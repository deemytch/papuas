require 'yaml'
require 'logger'
require 'pathname'

$base = Pathname.new(__FILE__).dirname.expand_path
ENV["BUNDLE_GEMFILE"] ||= "#{$base}/Gemfile"
require "rubygems"
require "bundler/setup"
    
require 'active_record'
require 'active_support'
require 'active_support/inflector'
require 'mysql2'

require_relative 'models/hash'

namespace :m do
  desc "Создание пустого файла миграции для класса ClassName"
  task :c do
    ARGV.each { |a| task a.to_sym do ; end } # потому что это аргументы а не задачи
    class_name = ARGV[1]
    table_name = class_name.tableize
    filename = Time.now.strftime "%Y%02m%02d%H%M%S" + "_create_#{class_name.underscore}.rb"
    puts "#{filename}"
    File.open "config/migrations/#{filename}", 'w' do |script|
      script.write <<~ENDSCRIPT
        class Create#{class_name} < ActiveRecord::Migration
        \tdef change
        \t\tcreate_table :#{table_name} do |t|
        \t\t\t
        \t\t\tt.timestamps null: false
        \t\tend
        \tend
        end
      ENDSCRIPT
    end
  end

end

namespace :db do
  def create_database config

    create_db = Proc.new {
      sql_user = <<~SQL_USER
        CREATE USER IF NOT EXISTS #{config[:username]} IDENTIFIED BY '#{config[:password]}';
        FLUSH PRIVILEGES;
      SQL_USER
      sql_db = "CREATE DATABASE IF NOT EXISTS #{config[:database]};"
      sql_grant = <<~SQLGRANT
          GRANT ALL PRIVILEGES ON #{config[:database]}.* 
            TO '#{config[:username]}'
            IDENTIFIED BY '#{config[:password]}';
      SQLGRANT

      `mysql -u root -Nse "#{sql_user}"`
      `mysql -u root -Nse "#{sql_db}"`
      `mysql -u root -Nse "#{sql_grant}"`
    }

    create_db.call config
    rescue Mysql2::Error => sqlerr
      puts "Ошибка номер #{sqlerr.errno}"
      if sqlerr.errno == 1405
        print "#{sqlerr.error}. \nPlease provide the root password for your mysql installation\n>"
        root_password = $stdin.gets.strip
        create_db.call config.merge(:database => nil, :username => 'root', :password => root_password)
      else
        $stderr.puts sqlerr.error
        $stderr.puts "Couldn't create database for #{config.inspect}, charset: utf8, collation: utf8_unicode_ci"
        $stderr.puts "(if you set the charset manually, make sure you have a matching collation)" if config[:charset]
      end
  end
 
  task :environment do
    DATABASE_ENV = (ENV['DATABASE_ENV'] || 'development').to_sym
    MIGRATIONS_DIR = ENV['MIGRATIONS_DIR'] || 'config/migrations'
  end

  task :configuration => :environment do
    $cfg = YAML.load_file("#{$base}/config/global.yml").symkeys
    @config = $cfg[:mysql][DATABASE_ENV]
    puts "db: #{$cfg[:mysql][DATABASE_ENV][:database]}"
  end

  task :configure_connection => :configuration do
    ActiveRecord::Base.establish_connection @config
    ActiveRecord::Base.logger = Logger.new STDOUT if @config['logger']
  end

  desc 'Create the database from config/database.yml for the current DATABASE_ENV'
  task :create => :configure_connection do
    create_database @config
  end

  desc 'Drops the database for the current DATABASE_ENV'
  task :drop => :configure_connection do
    ActiveRecord::Base.connection.drop_database @config[:database]
  end

  desc 'Migrate the database (options: VERSION=x, VERBOSE=false).'
  task :migrate => :configure_connection do
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migrator.migrate MIGRATIONS_DIR, ENV['VERSION'] ? ENV['VERSION'].to_i : nil
  end

  desc 'Rolls the schema back to the previous version (specify steps w/ STEP=n).'
  task :rollback => :configure_connection do
    step = ENV['STEP'] ? ENV['STEP'].to_i : 1
    ActiveRecord::Migrator.rollback MIGRATIONS_DIR, step
  end

  desc "Retrieves the current schema version number"
  task :version => :configure_connection do
    puts "Current version: #{ActiveRecord::Migrator.current_version}"
  end
end
