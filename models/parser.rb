require_relative 'listing'

class Parser
	def self.helptext
		<<-HELPTEXT
Примеры:
	# Добавить источник borman@op01
	#{$0} -S borman@op01:/home/borman/tasks -k /home/borman/borman_rsa -n

	# Удалить бормана@op01
	#{$0} -R borman@op01

	# Добавить целевой сервер user@glassfish
	#{$0} -N user@glassfish:4444/home/user/site/tasks
	
	#Добавить целевой узел jboss.co.spb, порт 2222, перечислен список логинов и соответствующих ключей
	#{$0} -N oivan@jboss.co.spb:2222/home/oivan -k /z/data/keys/oivan/rsa_id --nodename jboss \
	      -N jboss -l peterk -k /z/data/keys/peterk_rsakey.pem
	
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
	@@verbose = Logger::FATAL + 1
	lvls = %w[debug notice warn error fatal]
	OptionParser.new do |parser|
		parser.on('-S [URI]', '--source [URI]', String, 'Работа с источниками задач') do |uri|
			unless uri.nil?
				@@options << { :action => :add, :t => SourceNode, params: { uri: "ssh://#{uri}" }}
			else
				puts Listing.list_sources
				exit
			end
		end
		parser.on('-N [URI]', '--node [URI]', String, 'Работа с узлами назначения') do |uri|
			unless uri.nil?
				@@options << { :action => :add, :t => TaskNode, params: { uri: "ssh://#{uri}" }}
			else
				puts Listing.list_nodes
				exit
			end
		end
		parser.on('-U [name]', '--user [name]', String, 'Список аккаунтов') do |uri|
			puts Listing.list_nodes
			exit
		end
		parser.on('-R NAME', '--rm NAME', String, 'удаление записи по имени или URI') do |name|
			@@options << { :action => :del, params: name }
		end
		parser.on('-C [SERVER]', '--check [SERVER]', String, 'проверить правильность настроек записи (сервера и пользователя)') do |name|
			@@options << ( name ? { :action => :check, name: name } : { action: :check } )
		end
		parser.on('-T [id|uri|name]', '--tasks [id|uri|name]', String, 'Вывести статус задач. Поиск по id задачи, адресу или имени сервера') do |i|
				puts Listing.list_tasks(i)
				exit
		end
		parser.on('-l login', '--login login', String, 'Имя пользователя (login)') do |login|
			@@options.last[:params][:login] = login
		end
		parser.on('-n имя', '--name имя', String, 'Дать имя ресурсу') do |name|
			@@options.last[:params][:name] = name
		end
		parser.on('-e ФИО', '--name ФИО', String, 'Задать настоящее имя пользователя') do |name|
			@@options.last[:params][:realname] = name
		end
		parser.on('-k', '--key имя-файла', String, 'Имя файла с приватным ключом') do |fname|
			@@options.last[:params][:key] = fname
		end
		parser.on('-n', '--host hostname', String, 'адрес хоста') do |host|
			@@options.last[:params][:host] = host
		end
		parser.on('-d', '--dir папка', String, 'Путь') do |path|
			@@options.last[:params][:path] = path
		end
		parser.on('-p', '--port порт', Integer, 'Порт') do |port|
			@@options.last[:params][:port] = port
		end
		parser.on('-i описание', '--descr описание', String, 'Задать описание ресурса') do |descr|
			@@options.last[:params][:descr] = descr
		end
		parser.on('-L', '--logrotate', 'Архивация и очистка базы') do
			@@options << { :action => :logrotate }
		end
		parser.on('-P [NAME]', '--publish [NAME]', String, "Публикация справочника с целевыми узлами и логинами\n\t\t\t\t\tна каждый источник в файл *nodes.listing.yml*") do
			@@options << { :action => :publish }
		end
		parser.on('-v level', '--verbose (debug|notice|warn|error|fatal)', 'Разговорчивый режим, чтобы усилить - добавь ещё "v"') do |level|
			if level =~ /^(debug|notice|warn|error|fatal)$/
				@@verbose = lvls.find_index(level) if lvls.include?(level)
			else
				@@verbose -= 1
				@@verbose = 0 if @@verbose < 0
			end
		end
		parser.on('-z', '--zap', 'Удалить все записи, со статусом "удалено"') do
			@@options << { :action => :zap }
		end
		parser.on('-h', '--help', 'Справка'){ puts "#{parser}\n#{helptext}"; exit }
	end.parse!

	def self.options
		@@options
	end
	def self.verbose
		@@verbose
	end
end
