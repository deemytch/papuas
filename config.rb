require 'yaml'
require 'pathname'
require 'logger'
require 'fileutils'
require_relative 'models/logger'
require_relative 'models/hash'
require_relative 'models/string'

module Config
  def self.verbosity
    @@verbosity ||= %w[debug notice warn error fatal]
  end

  def self.start(app = :appsetup)
    $exitcode = 0
    $logger = Logger.new(STDERR)
    $logger.datetime_format = "%d/%m/%y %H:%M"
    $logger.level = Logger::INFO
    $base ||= File.expand_path(File.dirname(__FILE__))
    $cfg = YAML.load_file("#{$base}/config/global.yml").symkeys
    $logger.reopen($cfg[app][:log] == 'STDERR' ? STDERR : File.open($cfg[app][:log], 'a+'))
    FileUtils.mkpath $cfg[:global][:cachedir]
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
    require 'sidekiq'

    Sidekiq.configure_client do |config|
      config.redis = {
        size: 1,
        retry: false,
        url: "redis://#{$cfg[:redis][:host]}:/#{$cfg[:redis][:db]}"
      }
    end
    Sidekiq.configure_server do |config|
      config.redis = {
        retry: false,
        url: "redis://#{$cfg[:redis][:host]}:/#{$cfg[:redis][:db]}"
      }
    end

    $database_env = (ENV['DATABASE_ENV'] || 'development').to_sym
    # begin
      $db = ActiveRecord::Base.establish_connection($cfg[:mysql][$database_env])
      %w[errors task_report task server_account source_node task_node listing executor].each do |src|
        require_relative "#{$base}/models/#{src}.rb"
      end
      if $database_env == :test
        require_relative 'spec/helpers.rb'
        truncate_tables
      else
        # чистка мусора
        ServerAccount.with_deleted_state.each{|s| s.destroy }
      end
    # rescue ActiveRecord::StatementInvalid => e
    #   $logger.fatal "Таблиц нет. Растительности нет. Населена роботами. #{e}"
    # end
  end

  def self.setlock?
    File.new("/tmp/pjreq3.lock",'w').flock(File::LOCK_NB | File::LOCK_EX)
  end
  def self.unlock!
    File.new('/tmp/pjreq3.lock').flock(File::LOCK_UN)
  end

  def self.set_gad(lvl) # уровень разговорчивости. Если DEBUG|INFO - подключаем логгер к AR
    $logger.level = lvl
    if lvl <= Logger::INFO
      # $arlog = ActiveSupport::Logger.new($cfg[app][:log] == STDERR ? STDERR : File.open($cfg[app][:log], 'a+'))
      # $arlog.level = lvl
      ActiveRecord::Base.logger = $logger
    end
    $logger.info "Уровень разговорчивости #{$logger.level}"
  end

end
