#!/bin/sh
rake db:drop 
sleep 1
rake db:create db:migrate