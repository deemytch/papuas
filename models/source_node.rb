require 'net/ssh'
require 'net/scp'
require 'net/sftp'

class SourceNode < ServerAccount
	has_many :tasks
	has_many :task_reports, :through => :tasks, :dependent => :destroy

=begin
Ищем на host/path все файлы с именем doit-*yml
Грузим по очереди в Task
Если задача создана успешно, то переименовываем на исходном хосте их в taskloaded*
=end
	def on_processing_entry(new_state, event, *args)
		$logger.debug "SourceNode #{id} начал загрузку задач, статус #{status}"
		Net::SFTP.start(host, user, sshparams) do |sftp|
			sftp.dir.foreach(path) do |el|
				# СДЕЛАТЬ: потом тут можно распараллелить, если понадобится
				next unless el.name =~ /^doit-(.+)\.yml$/
				$logger.debug "Загружаю файл описания задачи #{el.longname}\n\t #{path}/#{el.name}"
				descr = $1
				yml = YAML.load(sftp.download!("#{path}/#{el.name}"))
				task = Task.new settings: yml, source_node: self
				unless task.save
					$logger.error "Ошибка создания задачи SourceNode##{id}/#{el.name}"
					next
				end
				dstname = el.name.gsub /^doit-/,"task-#{t.id}-"
				Net::SSH.start(host, user, sshparams) do |ssh|
					ssh.exec! "cd #{path} && mv '#{el.name}' '#{dstname}'"
				end
				# копирую файлы задачи ей в папку
				sftp.download! task.filelist.map{|f| "#{path}/#{f}" }, task.tmpdir
				# поехали!
				task.power!
			end
		end
	process_done!
	rescue SocketError => e
		$logger.error "Ошибка подключения к хосту ServerAccount##{id}"
		process_fail!
	rescue RuntimeError => e
		$logger.error "Ошибка чтения файла #{e}"
		process_fail!
	rescue Net::SFTP::StatusException => e
		$logger.error "Ошибка копирования файлов #{e}"
		process_fail!
	rescue Net::SSH::ConnectionTimeout => e
		$logger.error "Ошибка подключения #{e}"
		process_fail!
	end
end

=begin
	

		sshdata = { timeout: $cfg[:global][:timeout], :auth_methods=>%w[publickey hostbased] }
		if settings.nil? || settings.empty?
			errors.add :settings, "Где настройки задачи, я спрашиваю?" 
			return
		end
		if ! settings.key?('server') || ! settings.key?('script') || settings['server'].empty?
			errors.add :settings, 'Не хватает данных для задачи'
			return
		end
		settings['servers'].each do |srv, u|
			if (noda = Server.with_active_state.find_by(name: srv)).nil? ||
				(user = noda.users.with_active_state.find_by(name: u)).nil? then
					errors.add :settings, "Невозможно использовать #{u}@#{srv}"
			end
		end
		# мало ли какие файлы там надо скопировать, на всякий случай не буду их тащить в базу
		Net::SCP.start(source_node.host, source_node.users.last.login, sshdata) do |scp|
			self.data ||= Dir.mktmpdir "task-#{id}-", $cfg[:global][:tmpdir] # может уже всё есть?
			self.script = scp.download "#{source_node.path}/#{settings['script']}"
			scriptname = Pathname.new(settings['script']).basename
			File.new "#{data}/#{scriptname}", 'w' do |f|
				f.write script
			end
			if settings.key?('files')
				settings['files'].each do |fdata|
					scp.download "#{source_node.path}/#{fdata}", data
				end
			end
			scp.loop!
		end

	rescue SocketError => e
		errors.add :source_node_id, "Ошибка сети #{e}"		
	rescue Net::SSH::AuthenticationFailed => e
		errors.add :source_node_id, "Ошибка сети #{e}"
	rescue Net::SCP::Error => e
		errors.add :settings, "Обнаружено наличие отсутствия доступа к файлу #{e}. Проверь там чего-нибудь."	
=end