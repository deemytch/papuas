require 'yaml'
require 'pathname'
require 'logger'
require_relative 'models/hash'

module Config
  def self.start(app = :appsetup)
    $logger = Logger.new(STDERR)
    $logger.level = :debug
    $base ||= File.expand_path(File.dirname(__FILE__))
    $cfg = YAML.load_file("#{$base}/config/global.yml").symkeys
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
    require 'uri'

    $database_env = (ENV['DATABASE_ENV'] || 'development').to_sym
    begin
      $db = ActiveRecord::Base.establish_connection($cfg[:mysql][$database_env])
      %w[parser errors task_report task server_account source_node task_node listing executor].each do |src|
        require_relative "#{$base}/models/#{src}.rb"
      end
      if $database_env == :test
        require_relative 'spec/helpers.rb'
        truncate_tables
      else
        # чистка мусора
        ServerAccount.with_deleted_state.each{|s| s.destroy }
      end
    rescue ActiveRecord::StatementInvalid => e
      $logger.fatal "Таблиц нет. Растительности нет. Населена роботами. #{e}"
    end
  end
  def self.setlock?
    File.new("/tmp/pjreq3.lock",'w').flock(File::LOCK_NB | File::LOCK_EX)
  end
  def self.unlock!
    File.new('/tmp/pjreq3.lock').flock(File::LOCK_UN)
  end

  def self.set_gad # уровень разговорчивости. Если DEBUG|INFO - подключаем логгер к AR
    if Parser.verbose
      $logger.level = Parser.verbose
      if Parser.verbose <= Logger::INFO
        $arlog = ActiveSupport::Logger.new(STDERR)
        $arlog.level = Parser.verbose
        ActiveRecord::Base.logger = $arlog
      end
      $logger.debug "Уровень разговорчивости #{$logger.level}"
    end
  end

end
