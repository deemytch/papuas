#!/usr/bin/env ruby
=begin
  1. Проверить наличие базы
  2. Прочитать параметры командной строки
  3. Проверить непротиворечивость параметров и базы
  4. Сделать действие
=end
options = {}
if ARGV.empty?
  puts "\n\t\tСправка - по ключу -h\n\n"
  exit
end

require 'yaml'
require 'mysql2'
require 'optparse'
require 'sequel'
require 'logger'
require 'tty'
require 'sshkit'
require_relative './config.rb'
Sequel::Model.plugin :validation_helpers
Sequel::Model.plugin :timestamps, :update_on_create=>true
Sequel::Model.plugin :update_refresh
Sequel::Model.plugin :auto_validations, :not_null=>:presence
Sequel::Model.plugin :polymorphic
Sequel::Model.plugin :schema
DB = Sequel.mysql2 $cfg[:mysql]
%w[task_report user task server servers_user source_node task_node].each{|src| require_relative "models/#{src}.rb" }
logger = Logger.new STDERR

def helptext
'Примеры:
  # Добавить источник borman, сервер op01 есть в .ssh/config, но порт и логин другие
  -S borman -a borman -u borman -h op01 -p 6897 -d /home/borman/a/tasks
  
  # Добавить источник borman, все настройки сервера op01 есть в .ssh/config
  -S borman -a borman -h op01 -d /home/borman/a/tasks
  
  # Добавить источник, приватный ключ в файле privkey_borman.pem в текущей папке
  -S borman -a -u borman,privkey_borman.pem -h op01 -p 6897 -d /home/borman/a/tasks
  
  # Удалить источник борман
  -S -r borman
  
  # Поменять настройки бормана, теперь все задачи пишет Аня
  -S -m borman -u anja -d /home/borman/anja/tmp
  
  # Добавить целевой узел jboss.co.spb, порт 2222, перечислен список логинов и соответствующих ключей
  # ключ для Васи по умолчанию или указан в .ssh/config
  -N -a jboss-spb -u gregor,privkey_gregor.rsa -u manja,privkey_manja.pem,Марин\ Блюмкин -u vasja -h jboss.co.spb -p 2222
'
end
def logger(text)
  puts text if options[:verbose]
end

OptionParser.new do |parser|
  parser.on('-S', '--source', 'Работа с источниками задач'){ options[:ctrl] ||= :source }
  parser.on('-N', '--node', 'Работа с узлами назначения'){ options[:ctrl] ||= :node }
  parser.on('-U', '--user', 'Работа с пользователями'){ options[:ctrl] ||= :user }
  
  parser.on('-a', '--add name', String, 'добавление записи'){|name| options[:action] ||= :add; options[:name] = name }
  parser.on('-m', '--mod name', String, 'изменение записи'){|name| options[:action] ||= :mod; options[:name] = name }
  parser.on('-r', '--rm name', String, 'удаление записи'){|name| options[:action] ||= :del; options[:name] = name }
  parser.on('-l', '--list', 'Показать список'){ options[:action] ||= :listing }
  
# имя пользователя может содержать путь к ключу через двоеточие
  parser.on('-u', '--login name', String, 'Имя пользователя (login[,keyfile][,имя])') do |name|
    options[:users] ||= []
    options[:users] << name
  end
  parser.on('-n', '--host hostname', String, 'Имя или адрес хоста'){|host| options[:host] = host }
  parser.on('-d', '--dir папка', String, 'Путь, если необходимо'){|path| options[:path] = path }
  parser.on('-p', '--port порт', String, 'Порт, по умолчанию 22'){|port| options[:port] = port }
  parser.on('', '--descr описание', String, 'Дополнительная информация'){ |descr| options[:descr] = descr }
  parser.on('-L', '--logrotate', 'Архивация и очистка базы'){ options[:ctrl] = :logrotate }
  parser.on('-P', '--publish', "Публикация справочника с целевыми узлами и логинами\n\t\t\t\t\tна каждый источник в файл *nodes.listing.yml*") do
    options[:ctrl] = :publish
  end
  parser.on('-v', '--verbose', 'Разговорчивый режим')do
		options[:verbose] ||= 0
    options[:verbose] += 1
    DB.loggers << Logger.new(STDOUT) if options[:verbose] > 1
  end
  parser.on('-h', '--help', 'Справка'){ puts "#{parser}\n#{helptext}"; exit }
end.parse!

server = nil
case options[:ctrl]
  when :source
    case options[:action]
      when :add
        logger.info "Добавляю узел-источник #{options[:name]}" if options[:verbose]
        server = SourceNode.create options.with_keys(:name, :host, :path, :port)
        logger.info "#{server.nil? ? 'Неудачно' : 'Удачно' }" if options[:verbose]
      when :mod
        logger.info "Меняю узел-источник #{options[:name]}" if options[:verbose]
        server = SourceNode[name: options[:name]]
        server.set_fields options, :name, :host, :path, :port
        server.save
      when :del
        logger.info "Удаляю узел-источник #{options[:name]}" if options[:verbose]
        server = SourceNode[name: options[:name]]
        server.delete
      when :listing
				if (servers = SourceNode.all.collect{|node| [node.status, node.name, node.host, node.port, node.path, node.descr]}).any? then
					puts TTY::Table.new(
						%w[состояние имя адрес порт путь описание],
						servers, renderer: 'unicode')
				elsif options[:verbose]
					puts "Ничего нет"
				end
    end
  when :node
    case options[:action]
      when :add
        server = TaskNode.create options.with_keys(:name, :host, :port)
      when :mod
        server = TaskNode[name: options[:name]]
        server.set_fields options, :name, :host, :port
        server.save
      when :del
        server = TaskNode[name: options[:name]]
        server.delete
      when :listing
				if (nodes = TaskNode.all.collect{|node| [node.status, node.name, node.host, node.port, node.path, node.descr]}).any? then
					puts TTY::Table.new(
						header: %w[состояние имя адрес порт путь описание],
						rows: nodes,
						renderer: 'unicode')
				elsif options[:verbose]
				  puts "Ничего нет"
				end
    end
  when :user
    case options[:action]
      when :del
        logger.info "Удаляю пользователя #{options[:name]}"
        User[login: options[:name]].delete
      when :listing
        if (r = User.all.collect{|user| [user.name, user.login, user.key[0..40], user.status, user.source_nodes.collect{|sn| sn.name || "#{sn.host}:#{sn.port}/#{sn.path}" }, user.task_nodes.collect{|tn| tn.name || "#{tn.host}:#{tn.port}"}]}).any?
          puts TTY::Table.new(
            header: %w[имя логин ключ состояние источники узлы],
            rows: r,
            renderer: 'unicode')
        elsif options[:verbose]
          puts "\t\tНикого нет"
        end
    end
  when :logrotate
  when :publish
  
end

if options.key? :users
  logger.info "Добавляю пользователей: [#{options[:users].join(',')}]"
  options[:users].each do |creds|
    if creds =~ /,/ # задан ключ
      data = creds.split(',')
      login = data[0]
      keyfile = File.read(data[1])
      realname = data[2] if data.size > 2
    else
      login = creds
      keyfile = nil
      realname = nil
    end
    unless user = User[name: login, key: keyfile]
      user = User.new login: login
      user.key = keyfile if keyfile
      user.name = realname if realname
      user.save
      server.users << user
    end
  end
end

# логинимся для проверки и копируем туда-оттуда файлик
server.check! unless server.nil?
if ! server.nil? && ! server.check!
  logger.warn "Невозможно проверить корректность новой записи.\n#{options}\n#{server.inspect}" if options[:verbose]
  exit 1
end
