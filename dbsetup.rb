#!/usr/bin/env ruby
# Миграции и первоначальная настройка базы данных с нуля
require 'optparse'
require_relative './config.rb'
use_force = false

OptionParser.new do |parser|
  parser.on('-f', '--force', 'Насильно удалить старую базу') do
    use_force = true
  end
  parser.on('-h', '--help', 'Справка') do
    puts parser
    exit
  end
end.parse!

require 'sequel'
require 'sequel_enum'

DB = Sequel.mysql2 $cfg[:mysql]
Sequel::Model.plugin :validation_helpers
Sequel::Model.plugin :timestamps
Sequel::Model.plugin :update_refresh
Sequel::Model.plugin :auto_validations, :not_null=>:presence
Sequel::Model.plugin :polymorphic
Sequel::Model.plugin :schema
%w[task_report user task server servers_user].each{|src| require_relative "models/#{src}.rb" }

if use_force
  DB << "SET foreign_key_checks = 0" <<
    "DROP TABLE IF EXISTS #{ %w[tasks_reports users tasks servers servers_users].join(',') }" <<
    "SET foreign_key_checks = 1"
end

DB.transaction do
  [Server, Task, TaskReport, User, ServersUser].each{|k| k.create_table! }
end
