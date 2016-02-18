#!/usr/bin/ruby
# Миграции и первоначальная настройка базы данных с нуля
require 'optparse'
OptionParser.new do |parser|
  parser.on('-f', '--force', 'Насильно удалить старую базу') do
    File.unlink 'db.sqlite' if File.exist? 'db.sqlite'
  end
  parser.on('-h', '--help', 'Справка') do
    puts parser
    exit
  end
end.parse!

if File.exists?('db.sqlite') 
  puts "Файл с базой существует. Если он не нужен - удали его."
  exit 255
end

require 'sequel'
DB = Sequel.sqlite('db.sqlite')
Sequel::Model.plugin :validation_helpers, :timestamps
  
  DB.transaction do
    DB.create_table :nodes do
      primary_key :id
      String   :name,           null: false, unique: true
      Integer  :addr,           null: false
      Integer  :port
      String   :status,         null: false, index: true
      DateTime :created_at,     null: false
      DateTime :updated_at,     null: false
    end
    DB.create_table :source_paths do
      primary_key :id
      String   :name,           null: false, unique: true
      Integer  :addr,           null: false
      Integer  :port
      String   :path,           null: false
      String   :status,         null: false, index: true
      DateTime :created_at,     null: false
      DateTime :updated_at,     null: false
    end
    DB.create_table :tasks do
      primary_key :id
      foreign_key :source_path_id, :source_paths, index: true, null: false
      String   :settings,       null: false
      String   :script,         null: false
      String   :data
      DateTime :started_at
      DateTime :stopped_at
      String   :status, null: false, index: true
      DateTime :created_at,     null: false
      DateTime :updated_at,     null: false
    end
    DB.create_table :tasks_reports do
      primary_key :id
      foreign_key :task_id, :tasks, null: false, index: true
      foreign_key :node_id, :nodes, null: false, index: true
      Integer   :retcode
      String    :stdout_log
      String    :stderr_log
      DateTime  :started_at
      DateTime  :stopped_at
      String    :status, null: false, index: true
      DateTtime :created_at,     null: false
      DateTime  :updated_at,     null: false
      index [:task_id, :node_id], unique: true
    end
    DB.create_table :users do
      primary_key :id
      String :login,            null: false, index: true
      String :key,              null: false
      String :key_type,         null: false
      foreign_key :node_id, :nodes, null: false, index: true
      foreign_key :source_path_id, :source_paths, null: false, index: true
      String :status,  null: false, index: true
      index [:login, :node_id, :source_path_id], unique: true
    end
  end

