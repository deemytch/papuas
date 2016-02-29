require 'yaml'
require "pathname"

class Hash
  def symkeys
    Hash[self.map{|(k,v)| [k.to_sym, v.is_a?(Hash) ? v.symkeys : v]}]
  end
  def with_keys(*ks)
    list = ks
    self.select{|k,v| list.include? k }
  end
end

module Config
  $base ||= File.expand_path(File.dirname(__FILE__))
  $cfg = YAML.load(File.read("#{$base}/config/global.yml")).symkeys
  ENV["BUNDLE_GEMFILE"] ||= "#{$base}/Gemfile"
  require "rubygems"
  require "bundler/setup"
  
  # rubyver = '2.3.0'
  # ENV['PATH']= "#{$base}/vendor/ruby/2.3.0/bin"
  # ENV['RUBYOPT'] = '-rbundler/setup'
  # ENV['RUBYLIB'] = "#{ENV['HOME']}/.gem/ruby/#{rubyver}/gems/bundler-1.11.2/lib"
  # ENV['GEM_HOME'] = "#{$base}/vendor/ruby/#{rubyver}"
  # ENV['BUNDLE_GEMFILE'] = "#{$base}/Gemfile"
  
  
require 'yaml'
require 'mysql2'
require 'optparse'
require 'sequel'
require 'logger'
require 'tty'
require 'sshkit'

DB = Sequel.mysql2 $cfg[:mysql]

Sequel::Model.plugin :validation_helpers
Sequel::Model.plugin :timestamps, :update_on_create=>true
Sequel::Model.plugin :update_refresh
Sequel::Model.plugin :auto_validations, :not_null=>:presence
Sequel::Model.plugin :polymorphic
Sequel::Model.plugin :schema
%w[errors workflow_sequel task_report user task server servers_user source_node task_node].each{|src| require_relative "models/#{src}.rb" }

end
