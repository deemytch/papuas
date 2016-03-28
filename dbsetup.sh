#!/bin/sh
bundle exec rake db:drop
sleep 1
bundle exec rake db:create db:migrate
