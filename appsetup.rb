#!/usr/bin/ruby
=begin
  Флаг -h - вывести справку и отвалиться
  1. Проверить наличие базы
  2. Прочитать параметры командной строки
  3. Проверить непротиворечивость параметров и базы
  4. Сделать действие
=end

require 'yaml'
require 'mysql2'
require 'optparse'
require 'sequel'
require_relative './config.rb'
DB = Sequel.mysql2 $cfg[:mysql]
Sequel::Model.plugin :validation_helpers
Sequel::Model.plugin :timestamps
Sequel::Model.plugin :update_refresh
Sequel::Model.plugin :auto_validations, :not_null=>:presence
Sequel::Model.plugin :polymorphic
Sequel::Model.plugin :schema
%w[tasks_report user task server servers_user].each{|src| require_relative "models/#{src}.rb" }
options = {}

def helptext
'Примеры:
  # Добавить источник borman, сервер op01 есть в .ssh/config, но порт и логин другие
  -S borman -a borman -u borman -h op01 -p 6897 -d /home/borman/a/tasks
  
  # Добавить источник borman, все настройки сервера op01 есть в .ssh/config
  -S borman -a borman -h op01 -d /home/borman/a/tasks
  
  # Добавить источник, приватный ключ в файле privkey_borman.pem в текущей папке
  -S borman -a -u borman:privkey_borman.pem -h op01 -p 6897 -d /home/borman/a/tasks
  
  # Удалить источник борман
  -S -r borman
  
  # Поменять настройки бормана, теперь все задачи пишет Аня
  -S -m borman -u anja -d /home/borman/anja/tmp
  
  # Добавить целевой узел jboss.co.spb, порт 2222, перечислен список логинов и соответствующих ключей
  # ключ для Васи по умолчанию или указан в .ssh/config
  -N -a jboss-spb -u gregor:privkey_gregor.rsa -u manja:privkey_manja.pem -u vasja -h jboss.co.spb -p 2222
'
end
def logger(text)
  puts text if options[:verbose]
end

OptionParser.new do |parser|
  parser.on('-S', '--source', 'Работа с источниками задач'){ options[:ctrl] ||= :source }
  parser.on('-N', '--node', 'Работа с узлами назначения'){ options[:ctrl] ||= :node }
  parser.on('-U', '--user', 'Работа с пользователями'){ options[:ctrl] ||= :node }
  
  parser.on('-a', '--add name', String, 'добавление записи'){|name| options[:action] ||= :add; options[:name] = name }
  parser.on('-m', '--mod name', String, 'изменение записи'){|name| options[:action] ||= :mod; options[:name] = name }
  parser.on('-r', '--rm name', String, 'удаление записи'){|name| options[:action] ||= :del; options[:name] = name }

# имя пользователя может содержать путь к ключу через двоеточие
  parser.on('-l', '--login name', String, 'Имя пользователя (login)') do |name|
    options[:users] ||= []
    options[:users] << name
  end
  parser.on('-n', '--host hostname', String, 'Имя или адрес хоста'){|host| options[:host] = host }
  parser.on('-d', '--dir папка', String, 'Путь, если необходимо'){|path| options[:path] = path }
  parser.on('-p', '--port порт', String, 'Порт, по умолчанию 22'){|port| options[:port] = port }
  
  parser.on('-L', '--logrotate', 'Архивация и очистка базы'){ options[:ctrl] = :logrotate }
  parser.on('-P', '--publish', "Публикация справочника с целевыми узлами и логинами\n\t\t\t\t\tна каждый источник в файл *nodes.listing.yml*") do
    options[:ctrl] = :publish
  end
  parser.on('-v', '--verbose', 'Разговорчивый режим'){ options[:verbose] = true }
  parser.on('-h', '--help', 'Справка') do
    puts "#{parser}\n#{helptext}"
    exit
  end
end.parse!

server = nil
case options[:ctrl]
  when :source
    case options[:action]
      when :add
        server = SourcePath.create options.with_keys(:name, :host, :path, :port)
      when :mod
        server = SourcePath[name: options[:name]]
        server.set_fields options, :name, :host, :path, :port
        server.save
      when :del
        server = SourcePath[name: options[:name]]
        server.delete
    end
  when :node
    case options[:action]
      when :add
        server = Node.create options.with_keys(:name, :host, :port)
      when :mod
        server = Node[name: options[:name]]
        server.set_fields options, :name, :host, :port
        server.save
      when :del
        server = Node[name: options[:name]]
        server.delete
    end
  when :logrotate
  when :publish
    list = Node.all.collect do |node|
      
    end
end

if options[:users].any?
  options[:users].each do |creds|
    if creds =~ ':' # задан ключ
      login, keypath = creds.split(':')
      keyfile = File.read(keypath)
    else
      login = creds
      keyfile = nil
    end
    unless user = User[name: name, key: keyfile]
      user = User.new login: login
      user.key = keyfile if keyfile
      if server.class.is_a? Node
        user.node_id = server.id
      else
        user.source_path_id = server.id
      end
    end
  end
end
