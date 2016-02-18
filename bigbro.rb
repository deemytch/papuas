#!/usr/bin/ruby
require 'optparse'
require 'sequel'
DB = Sequel.sqlite('db.sqlite')
Sequel::Model.plugin :validation_helpers
Sequel::Model.plugin :timestamps
%w[user task task_report node source_path].each{|model| puts model; require_relative "models/#{model}.rb" }
