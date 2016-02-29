require 'yaml'
require 'pathname'
require 'logger'

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
  def self.start
    $base ||= File.expand_path(File.dirname(__FILE__))
    $cfg = YAML.load_file("#{$base}/config/global.yml").symkeys
    $logger = Logger.new $cfg[:global][:log]
    $logger.level = :error

    ENV["BUNDLE_GEMFILE"] ||= "#{$base}/Gemfile"
    require "rubygems"
    require "bundler/setup"
    require 'yaml'
    require 'mysql2'
    require 'workflow'
    require 'optparse'
    require 'active_record'
    require 'logger'
    require 'tty'
    require 'sshkit'

    $db = ActiveRecord::Base.establish_connection($cfg[:mysql][:development])
    %w[errors task_report user task server servers_user source_node task_node].each do |src|
      require_relative "#{$base}/models/#{src}.rb"
    end
  end
end
