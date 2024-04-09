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

cd /rails

case $1 in
  coonsole)
    echo "Service type is console"
    bundle exec rails c
    child=$!
    wait "$child"
    ;;

  web)
    echo "Service type is web"
    bundle exec rails s
    child=$!
    wait "$child"
    ;;

  sidekiq)
    echo "Run mode is sidekiq"
    bundle exec sidekiq -c ${SIDEKIQ_THREADS:-5} -q critical -q default -q low
    child=$!
    wait "$child"
    ;;

  nats)
    echo "Service type is nats"
    ./bin/rake custom_task:nats_subscribe
    child=$!
    wait "$child"
    ;;

  sleep)
    echo "Service type is sleep"
    sleep infinity
    child=$!
    wait "$child"
    ;;
esac
