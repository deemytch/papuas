#!/bin/sh

SIDEKIQ_PID=log/sidekiq.pid

case "$1" in
  start)
    bundle exec sidekiq -C config/sidekiq.yml -P $SIDEKIQ_PID
    bundle exec worker_ctl start
    ;;
  stop)
    bundle exec worker_ctl stop
    kill "$(cat $SIDEKIQ_PID)"
    ;;
  restart)
    # пока неясно как отслеживать вежливую остановку sidekiq
    ;;
esac
