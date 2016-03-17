require 'active_record'
require 'workflow'
require 'fileutils'
require 'net/sftp'
require 'sidekiq'

=begin
	Представление файла настроек задачи в базе.
	На входе - файл yml
	Создаёт папку в global.cachedir
	Копирует туда все исходные файлы
	Создает TaskReport для каждого целевого сервера, перечисленного в задании
	Запускает выполнение TaskReport
=end

class Task < ActiveRecord::Base
	serialize :settings
	include Workflow
	include Sidekiq::Worker
	workflow_column :status

	belongs_to :source_node
	has_many	:task_reports, :dependent => :destroy
		has_many :task_nodes, :through => :task_reports
	
	validate :yamlsettings
	after_save :mk_tmp, :on => :create
	before_save :get_descr, if: -> { self.changes.keys.include? 'settings' }
	before_save :parse_settings, if: -> { self.changes.keys.include? 'settings' }
	before_destroy :rm_tmp

	workflow do
		state :ready do
			event :power, :transition_to => :processing, meta: { instigator: self }
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

		# любая подзадача отчитывается о переходе в новое состояние
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
		if ! settings.key?('servers') || ! settings['servers'].is_a?(Array) ||
			! settings.key?('script') then
				errors.add :settings, "Неправильный файл задания."
		end
		settings['servers'].each do |name|
			unless TaskNode.with_active_state.id_name_uri(name).present?
				errors.add :settings, "Сервер задач #{name} не найден или выключен."
			end
		end
	end

	def start_process
		perform_async(self.id)
	end

	def self.perform(id)
		# теперь по каждому серверу создаем TaskReport, который будет выполнять скрипт
		(task = Task.find(id)).settings['servers'].each do |srv, u|
			noda = Server.with_active_state.find_by(name: srv)
			user = noda.users.with_active_state.find_by(name: u)
			tr = TaskReport.create task: task, task_node: noda, user: user
			if tr.nil?
				$logger.warn "Задача #{descr} для #{user.name}@#{node.name} не шмагла. Шоэтобыло?"
				next
			end
			tr.power!
		end
	end
	def mk_tmp
		tmpdir = "#{$cfg[:global][:cachedir]}/task-#{id}-#{ Time.now.strftime "%Y%m%d-%H%M%S" }"
		$logger.debug "Task #{id} mk_tmp #{tmpdir}"
		save
		FileUtils.mkpath tmpdir
	end
	def rm_tmp
		FileUtils.rm_r tmpdir if tmpdir.present?
	end
	def get_descr
		if settings.key?('descr') && ! settings['descr'].empty?
			self.descr = settings['descr']
		end
	end
	def parse_settings
		self.script = settings['script']
		settings['filelist'] ||= []
		settings['filelist'] << script
		(settings['filelist'] = settings['filelist'] | settings['files']) if settings.key?('files')
	end
	def filelist
		settings['filelist']
	end
end
