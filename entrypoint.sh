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

function check_db {
  echo "Checking Database"
  while ! mysqladmin ping -h mysql --silent; do
    echo "Waiting for mysql; sleep 1"
    sleep 1
  done
  if [[ ${RUN_MODE} == 'rspec' ]]; then
    echo "Creating test databases"
    ./scripts/setup_databases.sh
  fi
}

echo "Running: ${RUN_MODE}"

cd /rails

case ${RUN_MODE} in
  coonsole)
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
