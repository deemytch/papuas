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

require_relative './config.rb'
Config.start

def helptext
"Примеры:
	# Добавить источник borman, сервер op01 есть в .ssh/config, но порт и логин другие
	#{$0} -S borman -a -u borman -n op01 -p 6897 -d /home/borman/a/tasks
	
	# Добавить источник borman, все настройки сервера op01 есть в .ssh/config
	#{$0} -S borman -a -n op01 -d /home/borman/a/tasks
	
	# Добавить источник, приватный ключ в файле privkey_borman.pem в текущей папке
	#{$0} -S borman -a -u borman -k privkey_borman.pem -n op01 -p 6897 -d /home/borman/a/tasks
	
	# Удалить источник борман
	#{$0} -S borman -r 
	
	# Поменять настройки бормана, теперь все задачи пишет Аня
	#{$0} -S borman -m -u anja -d /home/borman/anja/tmp
	
	# Добавить целевой узел jboss.co.spb, порт 2222, перечислен список логинов и соответствующих ключей
	# ключ для Васи по умолчанию или указан в .ssh/config
	#{$0} -N jboss-spb -a -u gregor -k privkey_gregor.rsa\\
	 -u manja -k privkey_manja.pem --realname Марин\\ Блюмкин -u vasja -n jboss.co.spb -p 2222
	
	# На узел jboss теперь может заходить ещё и Ли Хуан
	#{$0} -U lihuan -a --nodename jboss-spb -u lihuan -k huanli_privkey --realname 'Li Khuan'
"
end
def logger(text)
	puts text if options[:verbose]
end

OptionParser.new do |parser|
	parser.on('-S', '--source name', 'Работа с источниками задач') do |name|
		options[:ctrl] ||= :source
		options[:name] = name
	end
	parser.on('-N', '--node name', 'Работа с узлами назначения') do |name|
		options[:ctrl] ||= :node
		options[:name] = name
	end
	parser.on('-U', '--user name', 'Работа с пользователями') do |name|
		options[:ctrl] ||= :user
		options[:name] = name
	end

	parser.on('-a', '--add', String, 'добавление записи')do |name|
		options[:action] ||= :add
	end
	parser.on('-m', '--mod', String, 'изменение записи') do |name|
	  options[:action] ||= :mod
	end
	parser.on('-r', '--rm', String, 'удаление записи') do |name|
		options[:action] ||= :del
	end
	parser.on('-c', '--check', String, 'проверить правильность настроек записи (сервера или пользователя)') do |name|
		options[:action] = :check
	end
	parser.on('-l', '--list', 'Показать список'){ options[:action] ||= :listing }
	
	parser.on('-u', '--login name', String, 'Имя пользователя (login)') do |name|
		options[:users] ||= []
		options[:users] << { name: name }
	end
	parser.on('-e', '--realname имя-пользователя', String, 'Настоящее имя пользователя') do |name|
		options[:users] ||= []
		if options[:users].empty? || options[:users].last.key?(:name)
			options[:users] << { name: name }
		else
			options[:users].last[:name] = name
		end
	end
	parser.on('-k', '--key имя-файла', String, 'Имя файла с приватным ключом')do |fname|
		options[:users] ||= []
		if options[:users].empty? || options[:users].last.key?(:key)
			options[:users] << { key: fname }
		else
			options[:users].last[:key] = fname
		end
	end
	
	parser.on('-t', '--nodename name', String, 'Задать имя источника задач'){|name| options[:nodename] = name }
	parser.on('-s', '--sourcename name', String, 'Задать имя узла назначения'){|name| options[:sourcename] = name }
	
	parser.on('-n', '--host hostname', String, 'Имя или адрес хоста'){|host| options[:host] = host }
	parser.on('-d', '--dir папка', String, 'Путь, если необходимо'){|path| options[:path] = path }
	parser.on('-p', '--port порт', String, 'Порт, по умолчанию 22'){|port| options[:port] = port }
	parser.on('-i', '--descr описание', String, 'Дополнительная информация'){ |descr| options[:descr] = descr }
	parser.on('-L', '--logrotate', 'Архивация и очистка базы'){ options[:ctrl] = :logrotate }
	parser.on('-P', '--publish [sourcename]', String, "Публикация справочника с целевыми узлами и логинами\n\t\t\t\t\tна каждый источник в файл *nodes.listing.yml*") do
		options[:ctrl] = :publish
	end
	parser.on('-v', '--verbose', 'Разговорчивый режим')do
		options[:verbose] ||= 0
		options[:verbose] += 1
	end
	parser.on('-h', '--help', 'Справка'){ puts "#{parser}\n#{helptext}"; exit }
end.parse!

server = nil
if options.key? :verbose
	$logger.level = options[:verbose]
	$logger.info "Уровень разговорчивости #{$logger.level}"
end

begin
	case options[:ctrl]
		when :source
			case options[:action]
				when :add
					$logger.info "Добавляю узел-источник #{options[:name]}" if options[:verbose]
					server = SourceNode.create options.with_keys(:name, :host, :path, :port)
					$logger.info "#{server.nil? ? 'Неудачно' : 'Удачно' }" if options[:verbose]
				when :mod
					$logger.info "Меняю узел-источник #{options[:name]}" if options[:verbose]
					server = SourceNode.find_by name: options[:name]
					server.update_attributes options.with_keys(:name, :host, :path, :port)
					server.save
				when :del
					$logger.info "Удаляю узел-источник #{options[:name]}" if options[:verbose]
					server = SourceNode name: options[:name]
					server.delete
				when :listing
					if (servers = SourceNode.all.collect{|node| [node.status, node.name, node.host, node.port, node.path, node.descr]}).any? then
						puts TTY::Table.new(
							%w[состояние имя адрес порт путь описание],
							servers, renderer: 'unicode')
					else
						raise EmptyList
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
				when :check
					$logger.debug "Проверяю данные #{options[:name]}" if options[:verbose]
					raise BadName if (server = TaskNode[name: options[:name]]).nil?
					raise BadHost if ! server.check!
					$logger.info "\t\t Сервер #{options[:name]} проверку прошёл"
				when :listing
					raise EmptyList if TaskNode.count == 0
					nodes = TaskNode.all.collect{|node| [node.status, node.name, node.host, node.port, node.path, node.descr, node.users.collect{|u| u.name.empty? ? u.login : u.name } ]}
					puts TTY::Table.new(
						header: %w[состояние имя адрес порт путь описание пользователи],
						rows: nodes ,
						renderer: 'unicode')
			end
		when :user
			case options[:action]
				when :del
					$logger.info "Удаляю пользователя #{options[:name]}"
					User[login: options[:name]].delete
				when :listing
					raise EmptyList if User.count == 0
					r = User.all.collect{|user| [user.id, user.name, user.login, user.key[0..40], user.status, user.source_nodes.collect{|sn| sn.name || "#{sn.host}:#{sn.port}/#{sn.path}" }, user.task_nodes.collect{|tn| tn.name || "#{tn.host}:#{tn.port}"}]}
					puts TTY::Table.new(
						header: %w[# имя логин ключ состояние источники узлы],
						rows: r,
						renderer: 'unicode')
				when :check
					raise BadName if (user = User[name: options[:name]]).nil?
					user.servers.each{|srv| srv.check! }
				when :logrotate
				when :publish
		
		end
	end

	if options.key?(:users)
	$logger.info "Добавляю пользователей: [#{options[:users].inspect}]"
		options[:users].each do |creds|
			raise BadUser if User[login: login, key: keyfile] || User[name: name, login: login]
			user = User.create creds
			server.users << user
		end
	end
	rescue BadUser => e
		$logger.error "\t\t Неправильный пользователь"
		e.user.checked_bad!
		exit 5
	rescue BadHost => e
		$logger.error "\t\t Сервер #{options[:name]} не отвечает"
		e.checked_bad!
		exit 4
	rescue EmptyList => e
		$logger.error "\t\t Никого нет"
		exit 3
	rescue BadName => e
		$logger.error "\t\t Имя #{options[:name]} не найдено в базе"
		exit 2
end
# логинимся для проверки и копируем туда-оттуда файлик
server.check! unless server.nil?
if ! server.nil? && ! server.check!
	$logger.warn "Невозможно проверить корректность новой записи.\n#{options}\n#{server.inspect}"
	exit 1
end
