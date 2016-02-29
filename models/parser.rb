class Parser
	def self.helptext
"Примеры:
	# Добавить источник borman, сервер op01 есть в .ssh/config, но порт и логин другие
	#{$0} -S borman -a -u borman -n op01 -p 6897 -d /home/borman/a/tasks
	# Удалить бормана
	#{$0} -N borman -r

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
# обрабатываем опции и записываем что сделать
	@@options = {}
	OptionParser.new do |parser|
		parser.on('-S', '--source [name]', String, 'Работа с источниками задач') do |name|
			@@options[:ctrl] ||= :source
			@@options[:name] = name
		end
		parser.on('-N', '--node [name]', String, 'Работа с узлами назначения') do |name|
			@@options[:ctrl] ||= :node
			@@options[:name] = name
		end
		parser.on('-U', '--user [name]', String, 'Работа с пользователями') do |name|
			@@options[:ctrl] ||= :user
			@@options[:name] = name
		end

		parser.on('-a', '--add', String, 'добавление записи')do |name|
			@@options[:action] ||= :add
		end
		parser.on('-m', '--mod', String, 'изменение записи') do |name|
		  @@options[:action] ||= :mod
		end
		parser.on('-r', '--rm', String, 'удаление записи') do |name|
			@@options[:action] ||= :del
		end
		parser.on('-c', '--check', String, 'проверить правильность настроек записи (сервера или пользователя)') do |name|
			@@options[:action] = :check
		end
		parser.on('-l', '--list', 'Показать список'){ @@options[:action] ||= :listing }
		
		parser.on('-u', '--login name', String, 'Имя пользователя (login)') do |name|
			@@options[:users] ||= []
			@@options[:users] << { name: name }
		end
		parser.on('-e', '--realname имя-пользователя', String, 'Настоящее имя пользователя') do |name|
			@@options[:users] ||= []
			if @@options[:users].empty? || @@options[:users].last.key?(:name)
				@@options[:users] << { name: name }
			else
				@@options[:users].last[:name] = name
			end
		end
		parser.on('-k', '--key имя-файла', String, 'Имя файла с приватным ключом')do |fname|
			@@options[:users] ||= []
			if @@options[:users].empty? || @@options[:users].last.key?(:key)
				@@options[:users] << { key: fname }
			else
				@@options[:users].last[:key] = fname
			end
		end
		
		parser.on('-t', '--nodename name', String, 'Задать имя источника задач'){|name| @@options[:nodename] = name }
		parser.on('-s', '--sourcename name', String, 'Задать имя узла назначения'){|name| @@options[:sourcename] = name }
		
		parser.on('-n', '--host hostname', String, 'Имя или адрес хоста'){|host| @@options[:host] = host }
		parser.on('-d', '--dir папка', String, 'Путь, если необходимо'){|path| @@options[:path] = path }
		parser.on('-p', '--port порт', String, 'Порт, по умолчанию 22'){|port| @@options[:port] = port }
		parser.on('-i', '--descr описание', String, 'Дополнительная информация'){ |descr| @@options[:descr] = descr }
		parser.on('-L', '--logrotate', 'Архивация и очистка базы'){ @@options[:ctrl] = :logrotate }
		parser.on('-P', '--publish [sourcename]', String, "Публикация справочника с целевыми узлами и логинами\n\t\t\t\t\tна каждый источник в файл *nodes.listing.yml*") do
			@@options[:ctrl] = :publish
		end
		parser.on('-v', '--verbose', 'Разговорчивый режим')do
			@@options[:verbose] ||= 0
			@@options[:verbose] += 1
		end
		parser.on('-h', '--help', 'Справка'){ puts "#{parser}\n#{helptext}"; exit }
	end.parse!
	def self.options
		@@options
	end
end