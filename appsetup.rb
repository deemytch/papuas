#!/usr/bin/ruby
=begin
  Флаг -h - вывести справку и отвалиться
  1. Проверить наличие базы
  2. Прочитать параметры командной строки
  3. Проверить непротиворечивость параметров и базы
  4. Сделать действие
=end

require 'yaml'
require 'sqlite3'
require 'optparse'
require 'sequel'
Dir["#{ File.expand_path(File.dirname(__FILE__)) }/models/*.rb"].each do |src|
  require_relative src
end

options = {}

def helptext
'Примеры:
  # Добавить источник borman, сервер op01 есть в .ssh/config, но порт и логин другие
  -S borman,borman@op01:6897/home/borman/a/tasks
  
  # Добавить источник borman, op01 есть в .ssh/config, логин отличается
  -S borman,borman@op01:/home/borman/a/tasks
  
  # Добавить источник borman, все настройки сервера op01 есть в .ssh/config
  -S borman,op01/home/borman/a/tasks
  
  # Добавить источник, приватный ключ в файле privkey_borman.pem в текущей папке
  -S borman,{borman:privkey_borman.pem}@op01:6897/home/borman/a/tasks
  
  # Удалить источник борман
  -D borman
  
  # Поменять настройки бормана, теперь все задачи пишет Аня
  -s borman,anja@op01:/home/borman/anja/tmp
  
  # Добавить целевой узел jboss.co.spb, порт 2222, перечислен список логинов и соответствующих ключей
  # ключ для Васи по умолчанию или указан в .ssh/config
  -N jboss-spb,{gregor:privkey_gregor.rsa,manja:privkey_manja.pem,vasja}@jboss.co.spb:2222
'
end
def logger(text)
  puts text if options[:verbose]
end

if ! File.exists?('db.sqlite') || ARGV.empty?
  puts helptext
  exit 255
end

DB = Sequel.sqlite('db.sqlite')
OptionParser.new do |parser|
  parser.on('-S', '--sourceAdd name,uri', Array, "Добавить источник") do |data|
    begin
      sp = SourcePath.new name: name, uri: uri
    rescue ParamsError => e
      puts e
      exit 255
    end
    logger "Добавляю источник задач: #{sp.name}"
    sp.save!
  end
  parser.on('-D', '--sourceDel name', String, 'Удалить источник') do |name|
    begin
      sp = SourcePath.find_by name: name
    rescue
    end
    logger "Удаляю источник #{name}"
  end
  parser.on('-s', '--sourceMod name,uri', Array, 'Изменить источник') do |src|
  end
  
  parser.on('-N', '--nodeAdd name,uri', Array, 'Добавить узел назначения') do |src|
  end
  parser.on('-r', '--nodeDel name', Array, 'Удалить узел') do |src|
  end
  parser.on('-n', '--nodeMod name,uri', Array, 'Изменить параметры узла') do |src|
  end
  
  parser.on('-l', '--logrotate', 'Архивация и очистка базы') do
  end
  parser.on('-p', '--publish', "Публикация справочника с целевыми узлами и логинами\n\t\t\t\t\tна каждый источник в файл *nodes.listing.yml*") do
  end
  parser.on('-v', '--verbose', 'Разговорчивый режим') do
    options[:verbose] = true
  end
  parser.on('-h', '--help', 'Справка') do |src|
    puts parser
    exit
  end
  parser.banner  = helptext + "\n\nСписок команд:\n"
end.parse!

def key2pem(src)
# СДЕЛАТЬ
  src
end

