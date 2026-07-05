#!/bin/bash

set -e

child=-1

_term() {
  echo "Caught SIGTERM signal!"
  kill -TSTP "$child" 2>/dev/null
  kill -TERM "$child" 2>/dev/null
  wait "$child"
}

trap _term SIGTERM

if [[ ! -z $1 ]]; then
  RUN_MODE=$1
fi

if [ -z "${RUN_MODE}" ]; then
  echo "RUN_MODE environment variable or first argument can be: console, web, sidekiq, nats, rspec, sleep"
  exit 1
fi

function migrate_databases {
  echo "Attempting to acquire migration lock"
  LOCK_RESULT=$(bundle exec rails runner "
    redis = Redis.new(url: ENV.fetch('SIDEKIQ_REDIS_URL'))
    if redis.set('db_migration_lock', Socket.gethostname, nx: true, ex: 600)
      puts 'acquired'
    elsif redis.exists?('db_migration_lock')
      puts 'in_progress'
    else
      puts 'completed'
    end
  " 2>&1 | tail -1)

  case "${LOCK_RESULT}" in
    acquired)
      echo "Migration lock acquired by this container; running migrations against all databases"
      bundle exec rails aodp:db:migrate
      bundle exec rails runner "
        Redis.new(url: ENV.fetch('SIDEKIQ_REDIS_URL')).del('db_migration_lock')
      "
      ;;
    in_progress)
      echo "Migrations are still in progress on another container; sleeping 5s before aborting so the orchestrator can retry"
      sleep 5
      exit 1
      ;;
    completed)
      echo "Migrations already completed by another container; continuing boot"
      ;;
    *)
      echo "Unexpected migration lock result: '${LOCK_RESULT}'; aborting"
      exit 1
      ;;
  esac
}

function check_db {
  echo "Checking Database"
  while ! mysqladmin ping -h mysql --silent; do
    echo "Waiting for mysql; sleep 1"
    sleep 1
  done
  if [[ ${RUN_MODE} == 'rspec' ]]; then
    echo "Creating test databases"
    ./scripts/setup_databases.sh
  else
    migrate_databases
  fi
}

echo "Running: ${RUN_MODE}"

cd /rails

case ${RUN_MODE} in
  console)
    check_db
    echo "Service type is console"
    bundle exec rails c
    child=$!
    wait "$child"
    ;;

  web)
    check_db
    echo "Service type is web"
    RUBY_YJIT_ENABLE=1 bundle exec rails s
    child=$!
    wait "$child"
    ;;

  sidekiq)
    check_db
    echo "Run mode is sidekiq"
    RUBY_YJIT_ENABLE=1 bundle exec sidekiq -c ${SIDEKIQ_THREADS:-5} -q critical -q default -q low
    child=$!
    wait "$child"
    ;;

  nats)
    echo "Service type is nats"
    ./bin/rake custom_task:nats_subscribe
    child=$!
    wait "$child"
    ;;

  rspec)
    check_db
    bundle exec rake spec
    ;;

  sleep)
    echo "Service type is sleep"
    sleep infinity
    child=$!
    wait "$child"
    ;;
esac
