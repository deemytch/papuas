=begin
  Занести все изменения в базу, с пометкой "не сейчас"
  если не выполняется никаких задач - записать всё
=end
module Executor
	def self.add_changes!(o)
		$logger.debug "Выполняю задачи: "
		o.each do |cmd|
			$logger.debug "#{cmd[:action]}"
			case cmd[:action]
			when :add # и :mod
				# begin
					# x = cmd[:t].host_or_uri(cmd[:name])
					x = cmd[:t].create!(cmd[:params])
					$logger.info "Создан объект #{x.class}: #{x.inspect};"
				# rescue StandardError => e
				# 	$logger.warn "Не удалось создать объект #{x}\n\t#{e}"
				# end
			when :mod
				begin
					if cmd[:params].key?(:name) &&
						! (user = User.find_by("name = ? OR login = ?", cmd[:name], cmd[:name])).nil? then
							user.update!(cmd[:params])
							$logger.info "Настройки пользователя #{cmd[:name]} теперь #{user.inspect}"
					else
						$logger.warn "Не найден пользователь с таким именем или логином: #{cmd[:name]}"
					end
				rescue StandardError => e
					$logger.warn "Не удалось создать объект User\n#{e}"
				end
			when :del

			when :check
				ServerAccount.where("status != 'deleted'").each{|node| node.check! }
			when :logrotate
				zap!
			when :publish
				repfn = "#{$cfg[:global][:tmpdir]}/#{$cfg[:appsetup][:publish]}"
				File.new(refn, 'w'){|f| f.write Listing.list_users	}
				chan = []
				SourceNode.with_active_state.each{|node| node.login{|ssh| chan << ssh.scp.upload(repfn, node.uri) } }
				chan.each{|c| c.wait }
			when :zap
				zap!
			end
		end
	end
	def self.perform
		if Config.flock?
		end
	end
	def self.zap!
		ServerAccount.with_deleted_state.each{|n| n.destroy }
		Task.with_deleted_state.each{|n| n.destroy }
	end
end

=begin









	# Обработка команд. Если что-то пошло не так - кидаю исключение в конец файла
begin
	server = nil # сначала добавляю сервер, потом к нему подключаю пользователей
	case options[:ctrl]
		when :source
			case options[:action]
				when :add
					$logger.info "Добавляю узел-источник #{options[:name]}"
					server = SourceNode.create options.with_keys(:name, :host, :path, :port)
					$logger.info "#{server.nil? ? 'Неудачно' : 'Удачно' }"
				when :mod
					$logger.info "Меняю узел-источник #{options[:name]}"
					server = SourceNode.find_by name: options[:name]
					server.update_attributes options.with_keys(:name, :host, :path, :port)
					server.save
				when :del
					$logger.info "Удаляю узел-источник #{options[:name]}"
					server = SourceNode.find_by name: options[:name]
					server.delete
				when :check
					$logger.debug "Проверяю данные #{options.key?(:name) ? options[:name] : 'всех источников'}"
					names = options.key?(:name) ? 
						((options[:name] =~ /,/) ? options[:name].split(',') : [options[:name]]) :
						SourceNode.where.not(:status => :deleted).pluck(:name)
					names.each do |nn|
						raise BadName if (server = SourceNode.find_by(name: options[:name])).nil?
						server.check!
						$logger.info "\t\t Сервер #{options[:name]} проверку #{'не' unless server.active?} прошёл"
					end
					exit 0
				when :listing
					raise EmptyList if SourceNode.count == 0
					servers = SourceNode.all.collect{|node| [node.status, node.name, node.host, node.port, node.path, node.descr, node.users.collect{|u| u.name.empty? ? u.login : u.name }]}
					puts TTY::Table.new(
						%w[состояние имя адрес порт путь описание пользователи],
						servers, renderer: 'unicode')
			end
		when :node
			case options[:action]
				when :add
					server = TaskNode.create options.with_keys(:name, :host, :port)
				when :mod
					raise BadName if (server = TaskNode.find_by(name: options[:name])).nil?
					server.update_attributes options.with_keys(:name, :host, :port)
					server.save
				when :del
					raise BadName if (server = TaskNode.find_by(name: options[:name])).nil?
					server.destroy
				when :check
					$logger.debug "Проверяю данные #{options.key?(:name) ? options[:name] : 'всех узлов'}"
					names = options.key?(:name) ? 
						((options[:name] =~ /,/) ? options[:name].split(',') : [options[:name]]) :
						TaskNode.where.not(:status => :deleted).pluck(:name)
					names.each do |nn|
						raise BadName if (server = TaskNode.find_by(name: options[:name])).nil?
						server.check!
						$logger.info "\t\t Сервер #{options[:name]} проверку #{'не' unless server.active?} прошёл"
					end
					exit 0
				when :listing
					raise EmptyList if TaskNode.count == 0
					nodes = TaskNode.all.collect{|node| [node.id, node.status, node.name, node.host, node.port, node.path, node.descr, node.users.pluck(:name) ]}
					puts TTY::Table.new(
						header: %w[# состояние имя адрес порт путь описание пользователи],
						rows: nodes,
						renderer: 'unicode')
			end
		when :user
			case options[:action]
				when :del
					$logger.info "Удаляю пользователя #{options[:name]}"
					User.find_by(login: options[:name]).destroy
				when :listing
					raise EmptyList if User.count == 0
					r = User.all.collect{|user| [user.id, user.status, user.name, user.login, (user.key.nil? ? '-' : user.key[0..40]), user.source_nodes.pluck(:name), user.task_nodes.pluck(:name) ]}
					puts TTY::Table.new(
						header: %w[# состояние имя логин ключ источники узлы],
						rows: r,
						renderer: 'unicode')
				when :check
					raise BadName if (user = User.find_by(name: options[:name])).nil?
					user.servers.each{|srv| srv.check! }
				when :logrotate
				when :publish
		
		end
	end

	if options.key?(:users)
	$logger.info "Добавляю пользователей: #{options[:users].inspect}"
		options[:users].each do |creds|
			user = User.find_or_create_by(creds)
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

end
=end