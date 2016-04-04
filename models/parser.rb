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
	def self.do
		@@options = {
			commands: [],
			flags: { :render => :unicode, :verbose => Logger::INFO }
		}
		
		OptionParser.new do |parser|
			parser.on('-S [id|name|URI]', '--source [id|name|URI]', String,
				'Работа с источниками задач') do |name|
				@@options[:commands] << 
					( name.nil? ? { :action => :list, :t => SourceNode } :
												{ :action => :add, :t => SourceNode, name: name} )
			end
			parser.on('-N [id|name|URI]', '--node [id|name|URI]', String,
				'Работа с узлами назначения') do |name|
					@@options[:commands] <<
						( name.nil? ? { :action => :list, :t => TaskNode } :
													{ :action => :add, :t => TaskNode, name: name })
			end
			parser.on('-U [id|name]', '--user [id|name]', String, 'Список аккаунтов') do |name|
				@@options[:commands] << { :action => :list, :t => ServerAccount, name: name }
			end
			parser.on('-R name|uri|id', '--rm name|uri|id', String,
				'удаление записи по имени, ID или URI; %ID для номера задачи') do |name|
				@@options[:commands] << { t: ((name =~ /^%/) ? Task : ServerAccount), :action => :del, name: name }
			end
			parser.on('-C [name|uri|id]', '--check [name|uri|id]', String,
				'зайти на сервер для проверки настроек') do |name|
				@@options[:commands] << ( name ? { :action => :check, name: name } : { action: :check } )
			end
			parser.on('-T [id|uri|name]', '--tasks [id|uri|name]', String,
				'Вывести статус задач. Поиск по id задачи, адресу или имени сервера') do |i|
					@@options[:commands] << { :action => :tasklist }
			end
			parser.on('', '--remote [id|uri|name]', String, 'Вывести статус на удалённые сервера') do |name|
				@@options[:commands].last[:action] = :publish
				@@options[:commands].last[:remote] = name
			end
			parser.on('--render [basic|ascii|remote]', String, 'Формат вывода таблиц') do |fmt|
				if fmt =~ /^(basic|ascii|unicode)$/
					@@options[:flags][:render] = fmt.to_sym
				end
			end
			parser.on('', '--off', 'Временно исключить хост, заданный в директиве -N или -T') do
				@@options[:commands].last[:action] = :off
			end
			parser.on('', '--on', 'Временно исключить хост, заданный в директиве -N или -T') do
				@@options[:commands].last[:action] = :on
			end
			parser.on('-u uri', '--uri uri', String, 'URI') do |uri|
				@@options[:commands].last[:params] ||= {}
				@@options[:commands].last[:params][:uri] = uri
			end
			parser.on('-l login', '--login login', String, 'Имя пользователя (login)') do |login|
				@@options[:commands].last[:params] ||= {}
				@@options[:commands].last[:params][:login] = login
			end
			parser.on('-n имя', '--name имя', String, 'Дать имя ресурсу') do |name|
				@@options[:commands].last[:params] ||= {}
				@@options[:commands].last[:params][:name] = name
			end
			parser.on('-e ФИО', '--fullname ФИО', String, 'Задать настоящее имя пользователя') do |name|
				@@options[:commands].last[:params] ||= {}
				@@options[:commands].last[:params][:realname] = name
			end
			parser.on('-k', '--key имя-файла', String, 'Имя файла с приватным ключом') do |fname|
				@@options[:commands].last[:params] ||= {}
				@@options[:commands].last[:params][:key] = fname
			end
			parser.on('-d', '--dir папка', String, 'Путь') do |path|
				@@options[:commands].last[:params] ||= {}
				@@options[:commands].last[:params][:path] = path
			end
			parser.on('-p', '--port порт', Integer, 'Порт') do |port|
				@@options[:commands].last[:params] ||= {}
				@@options[:commands].last[:params][:port] = port
			end
			parser.on('-i описание', '--descr описание', String, 'Задать описание ресурса') do |descr|
				@@options[:commands].last[:params] ||= {}
				@@options[:commands].last[:params][:descr] = descr
			end
			parser.on('-L', '--logrotate', 'Архивация и очистка базы') do
				@@options[:commands] << { :action => :logrotate }
			end
			parser.on('-v [level]', '--verbose [(debug|notice|warn|error|fatal)]', String,
				'Разговорчивый режим, чтобы усилить - добавь ещё "v"') do |level|
				if level =~ /^(debug|notice|warn|error|fatal)$/
					@@options[:flags][:verbose] = Config.verbosity.find_index(level) if Config.verbosity.include?(level)
				else
					@@options[:flags][:verbose] -= 1
					@@options[:flags][:verbose] = 0 if @@options[:flags][:verbose] < 0
				end
				Config.set_gad @@options[:flags][:verbose]
			end
			parser.on('-z', '--zap', 'Удалить все записи, со статусом "удалено"') do
				@@options[:commands] << { :action => :zap }
			end
			parser.on('-h', '--help', 'Справка'){ puts "#{parser}\n#{helptext}"; exit }
		end.parse!
		return @@options
	end
	
	def self.options
		@@options ||= Parser.do
		return @@options
	end
end
