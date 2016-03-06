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
  def self.start(app = :appsetup)
    $base ||= File.expand_path(File.dirname(__FILE__))
    $cfg = YAML.load_file("#{$base}/config/global.yml").symkeys
    $logger = Logger.new eval($cfg[app][:log])
    # $logger = Logger.new $cfg[app][:log]
    $logger.level = :debug

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
    $database_env = (ENV['DATABASE_ENV'] || 'development').to_sym
    begin
      $db = ActiveRecord::Base.establish_connection($cfg[:mysql][$database_env])
      %w[parser errors task_report user task server users_server source_node task_node].each do |src|
        require_relative "#{$base}/models/#{src}.rb"
      end
      if $database_env == :test
        require_relative 'spec/helpers.rb'
        truncate_tables
      else
        # чистка мусора
        User.with_deleted_state.each{|u| u.destroy }
        Server.with_deleted_state.each{|s| s.destroy }
      end
    rescue ActiveRecord::StatementInvalid => e
      $logger.fatal "Таблиц нет. Растительности нет. Населена роботами. #{e}"
    end
  end
end
