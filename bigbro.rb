#!/usr/bin/ruby
require 'optparse'
require 'sequel'
require_relative 'models/config.rb'
DB = Sequel.mysql('pjreq', user: 'pjreq', password: 'ababagalamaga')
Sequel::Model.plugin :validation_helpers
Sequel::Model.plugin :timestamps
%w[user task task_report node source_path].each{|model| puts model; require_relative "models/#{model}.rb" }

# Сначала пингуем наличие серверов и ищем есть ли новые задачи
SourcePath[status: [:active, :failed]].each{|src| src.check! ; src.load_tasks! }
Node[status: [:active, :failed]].each{|n| n.check! }
# Теперь можно и позапускать всё
Task[:status => :new].each{|task| task.run! }
