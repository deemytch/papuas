require 'active_record'
require 'workflow'
require 'fileutils'
require 'net/sftp'
require 'sidekiq'

=begin
 Представление файла настроек задачи в базе.
 На входе - файл yml
 Проверяет наличие исходных файлов и записывает объекты TaskReport
 по количеству узлов, на которых выполняется данная задача
=end
class Task < ActiveRecord::Base
	serialize :settings
	include Workflow
	include Sidekiq::Worker
	workflow_column :status

	belongs_to :source_node
	has_many	:task_reports, :dependent => :destroy
		has_many :task_nodes, :through => :task_reports
	
	validate :yamlsettings # побочные эффекты!
	before_destroy :rm_tmp

	workflow do
		state :new do
			event :passed, :transition_to => :ready, meta: { instigator: self }
			event :failed, :transition_to => :deleted, meta: { instigator: self }
		end
		state :ready do
			event :start_process, :transition_to => :processing, meta: { instigator: self }
			event :failed, :transition_to => :new, meta: { instigator: self }
		end
		state :processing do
			event :all_right, :transition_to => :done, meta: { instigator: self }
			event :task_failed, :transition_to => :fail, meta: { instigator: self }
			event :script_failed, :transition_to => :daemon_problems, meta: { instigator: self }
		end
		state :fail do
			event :restart, :transition_to => :ready, meta: { instigator: self }
			event :remove, :transition_to => :deleted, meta: { instigator: self }
		end
		state :daemon_problems do
			event :restart, :transition_to => :ready, meta: { instigator: self }
		end
		state :done
		state :deleted

		# любая подзадача может отчитаться о переходе в новое состояние
		# если все подзадачи имеют такой же статус, меняем статус задачи
		# если же событие вызвано для этой задачи, то оно передаётся всем подзадачам
		before_transition do |from, to, triggering_event, *event_args|
			if triggering_event.meta[:instigator].class == TaskReport &&
				task_reports.ids.include?(triggering_event.meta[:instigator].id) then
					self.call "#{triggering_event}!"
			end
		end

		after_transition do |from, to, triggering_event, *event_args|
			if triggering_event.meta[:instigator].id == id
				task_reports.each{|r| r.call "#{triggering_event}!" }
			end
		end
	end

	def yamlsettings
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
	end

	def start_process
		self.perform_async
	end

	def perform
		# теперь по каждому серверу создаем TaskReport, который будет выполнять скрипт
		settings['servers'].each do |srv, u|
			noda = Server.with_active_state.find_by(name: srv)
			user = noda.users.with_active_state.find_by(name: u)
			tr = TaskReport.create task: self, task_node: noda, user: user
			if tr.nil?
				$logger.warn "Задача #{descr} для #{user.name}@#{node.name} не шмагла. Шоэтобыло?"
				next
			end
		end
	end

	def rm_tmp
		FileUtils.rm_r data if data.present?
	end

end
