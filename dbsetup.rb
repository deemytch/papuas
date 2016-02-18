#!/usr/bin/ruby
# Миграции и первоначальная настройка базы данных с нуля
require 'optparse'
require_relative 'models/config.rb'

force = false

OptionParser.new do |parser|
  parser.on('-f', '--force', 'Насильно удалить старую базу') do
    force = true
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
begin
  DB << "DROP TABLE #{ [:nodes, :tasks, :source_paths, :task_reports, :users].join(',') }" if force
rescue
end

DB.transaction do
  DB.create_table :nodes do
    primary_key :id
    String   :name,           null: false, unique: true
    Integer  :addr,           null: false
    Integer  :port, null: false, default: 22
    column   :status, "enum('new', 'active', 'failed', 'deleted')", :default => 'new', null: false, index: true
    DateTime :created_at,     null: false
    DateTime :updated_at,     null: false
  end
  DB.create_table :source_paths do
    primary_key :id
    String   :name,           null: false, unique: true
    Integer  :addr,           null: false
    Integer  :port, null: false, default: 22
    String   :path,           null: false
    column   :status, "enum('new', 'active', 'failed', 'deleted')", :default => 'new', null: false, index: true
    DateTime :created_at, null: false
    DateTime :updated_at, null: false
  end
  DB.create_table :tasks do
    primary_key :id
    Integer :source_path_id, null: false, index: true
      foreign_key [:source_path_id], :source_paths
    String   :settings,       null: false
    String   :script,         null: false
    String   :data
    DateTime :started_at
    DateTime :stopped_at
    column   :status, "enum('new', 'active', 'done', 'failed')", :default => 'new', null: false, index: true
    DateTime :created_at, null: false
    DateTime :updated_at, null: false
  end
  DB.create_table :tasks_reports do
    primary_key :id
    Integer :task_id, null: false, index: true
      foreign_key [:task_id], :tasks
    Integer :node_id, null: false, index: true
      foreign_key [:node_id], :nodes
    Integer   :retcode
    String    :stdout_log
    String    :stderr_log
    DateTime  :started_at
    DateTime  :stopped_at
    column    :status, "enum('new', 'active', 'done', 'failed')", :default => 'new', null: false, index: true
    DateTime :created_at, null: false
    DateTime :updated_at, null: false
    index [:task_id, :node_id], unique: true
  end
  DB.create_table :users do
    primary_key :id
    String :login,            null: false, index: true
    String :key,              null: false
    String :key_type,         null: false
    Integer :node_id, null: false, index: true
      foreign_key [:node_id], :nodes
    Integer :source_path_id, null: false, index: true
      foreign_key [:source_path_id], :source_paths
    column    :status, "enum('new', 'active', 'failed', 'deleted')", :default => 'new', null: false, index: true
    index [:login, :node_id, :source_path_id], unique: true
  end
end
