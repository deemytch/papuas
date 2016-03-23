require_relative 'listing'

class Parser
	def self.helptext
		<<-HELPTEXT
Примеры:
	# Добавить источник borman@op01
	#{$0} -S op1 -u borman@op01:/home/borman/tasks -k /home/borman/borman_rsa

	# Удалить бормана@op01
	#{$0} -R op1

	# Добавить целевой сервер user@glassfish
	#{$0} -N glassf -u user@glassfish:4444/home/user/site/tasks
	
	#Добавить целевой узел jboss.co.spb, порт 2222, перечислен список логинов и соответствующих ключей
	#{$0} -N oivan@jbos -u oivan@jboss.co.spb:2222/home/oivan -k /z/data/keys/oivan/rsa_id --nodename jboss \
	      -N jboss -l peterk -k /z/data/keys/peterk_rsakey.pem
	# имя первой записи будет oivan@jbos
	# второй - peterk@jboss


	#peterk - Петя Каблуков
	#{$0} -U peterk --realname 'Петя Каблуков'

	#op01 - IBM/360 в Самаре
	#{$0} -N op01 --descr 'IBM/360 в Самаре'

	# На узел jboss теперь может заходить ещё и Ли Хуан
	#{$0} -N lihuan@jboss-spb:2222 -k huanli_privkey --realname 'Li Khuan'

	# Посмотреть все источники
	#{$0} -N

HELPTEXT
	end
=begin
  обрабатываем опции и записываем что сделать
  список действий с параметрами
	[ { action=:add|:rm|:mod,

		t: class
		uri: "ssh://" + URI
		}]
=end
	@@options = []
	verbose = Logger::WARN
	lvls = %w[debug notice warn error fatal]
	OptionParser.new do |parser|
		parser.on('-S [id|name|URI]', '--source [id|name|URI]', String,
			'Работа с источниками задач') do |name|
			unless name.nil?
				@@options << { :action => :add, :t => SourceNode, name: name}
			else
				puts Listing.list_sources
				exit
			end
		end
		parser.on('-N [id|name|URI]', '--node [id|name|URI]', String,
			'Работа с узлами назначения') do |name|
			unless name.nil?
				@@options << { :action => :add, :t => TaskNode, name: name }
			else
				puts Listing.list_nodes
				exit
			end
		end
		parser.on('-U [id|name]', '--user [id|name]', String, 'Список аккаунтов') do |name|
			puts Listing.list_servers name
			exit
		end
		parser.on('-R name|uri|id', '--rm name|uri|id', String,
			'удаление записи по имени, ID или URI; %ID для номера задачи') do |name|
			@@options << { t: ((name =~ /^%/) ? Task : ServerAccount), :action => :del, name: name }
		end
		parser.on('-C [name|uri|id]', '--check [name|uri|id]', String,
			'зайти на сервер для проверки настроек') do |name|
			@@options << ( name ? { :action => :check, name: name } : { action: :check } )
		end
		parser.on('-T [id|uri|name]', '--tasks [id|uri|name]', String,
			'Вывести статус задач. Поиск по id задачи, адресу или имени сервера') do |i|
				puts Listing.list_tasks(i)
				exit
		end
		parser.on('', '-off', 'Временно исключить хост, заданный в директиве -N или -T') do
			@@options.last[:action] = :off
		end
		parser.on('-u uri', '--uri uri', String, 'URI') do |uri|
			@@options.last[:params] ||= {}
			@@options.last[:params][:uri] = uri
		end
		parser.on('-l login', '--login login', String, 'Имя пользователя (login)') do |login|
			@@options.last[:params] ||= {}
			@@options.last[:params][:login] = login
		end
		parser.on('-n имя', '--name имя', String, 'Дать имя ресурсу') do |name|
			@@options.last[:params] ||= {}
			@@options.last[:params][:name] = name
		end
		parser.on('-e ФИО', '--fullname ФИО', String, 'Задать настоящее имя пользователя') do |name|
			@@options.last[:params] ||= {}
			@@options.last[:params][:realname] = name
		end
		parser.on('-k', '--key имя-файла', String, 'Имя файла с приватным ключом') do |fname|
			@@options.last[:params] ||= {}
			@@options.last[:params][:key] = fname
		end
		parser.on('-d', '--dir папка', String, 'Путь') do |path|
			@@options.last[:params] ||= {}
			@@options.last[:params][:path] = path
		end
		parser.on('-p', '--port порт', Integer, 'Порт') do |port|
			@@options.last[:params] ||= {}
			@@options.last[:params][:port] = port
		end
		parser.on('-i описание', '--descr описание', String, 'Задать описание ресурса') do |descr|
			@@options.last[:params] ||= {}
			@@options.last[:params][:descr] = descr
		end
		parser.on('-L', '--logrotate', 'Архивация и очистка базы') do
			@@options << { :action => :logrotate }
		end
		parser.on('-P [NAME]', '--publish [NAME]', String,
			"Публикация справочника с целевыми узлами и логинами\n\t\t\t\t\tна каждый источник в файл *nodes.listing.yml*") do
			@@options << { :action => :publish }
		end
		parser.on('-v [level]', '--verbose [(debug|notice|warn|error|fatal)]', String,
			'Разговорчивый режим, чтобы усилить - добавь ещё "v"') do |level|
			if level =~ /^(debug|notice|warn|error|fatal)$/
				verbose = lvls.find_index(level) if lvls.include?(level)
			else
				verbose -= 1
				verbose = 0 if verbose < 0
			end
			Config.set_gad verbose
		end
		parser.on('-z', '--zap', 'Удалить все записи, со статусом "удалено"') do
			@@options << { :action => :zap }
		end
		parser.on('-h', '--help', 'Справка'){ puts "#{parser}\n#{helptext}"; exit }
	end.parse!

	def self.options
		@@options
	end
end
