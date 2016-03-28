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
	sidekiq_options :retry => false, :backtrace => true

	belongs_to :source_node
	has_many	:task_reports, :dependent => :destroy
		has_many :task_nodes, :through => :task_reports
	
	validate :yamlsettings
	before_save :get_descr, if: -> { self.changes.keys.include? 'settings' }
	before_save :parse_settings, if: -> { self.changes.keys.include? 'settings' }
	after_create :mk_tmp
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
			meta = Task.workflow_spec.states[from].events[triggering_event].first.meta
			$logger.debug "будет переход Task #{id} #{from} -> #{to} :#{triggering_event}, #{event_args.inspect}, meta: #{meta.inspect}"
			# meta = Task.workflow_spec.states[from].events[triggering_event].meta
			# if meta[:instigator].class == TaskReport &&
			# 	task_reports.ids.include?(meta[:instigator].id) then
			# 		self.call "#{triggering_event}!"
			# end
		end

		after_transition do |from, to, triggering_event, *event_args|
			meta = Task.workflow_spec.states[from].events[triggering_event].first.meta
			$logger.debug "был переход Task #{id} #{from} -> #{to} :#{triggering_event}, #{event_args.inspect}, meta: #{meta.inspect}"
			# meta = Task.workflow_spec.events[triggering_event].meta
			# if meta[:instigator].id == id
			# 	task_reports.each{|r| r.call "#{triggering_event}!" }
			# end
		end
	end

	def yamlsettings
		$logger.debug "Task. Проверяю проверки. #{settings.inspect}"
		if ! settings.key?('servers') || ! settings['servers'].is_a?(Array) ||
			! settings.key?('script') then
				errors.add :settings, "Неправильный файл задания."
		end
		settings['servers'].each do |name|
			unless TaskNode.with_active_state.id_name_uri(name).any?
				errors.add :settings, "Сервер задач #{name} не найден или выключен."
			end
		end
		source_node.login do |ssh|
			# проверить наличие скрипта и доп. файлов на SourceNode
			([settings['script']] | (settings['files'] || [])).each do |f|
				a = ssh.exec!("[ -f #{source_node.path}/#{settings['script']} ] ; echo $?").chomp.to_i
				errors.add :settings, "Файл #{f} не найден на #{source_node.name}" unless a == 0
			end
		end
	end

	def on_processing_entry(new_state, event, *args)
		self.class.do(self.id)
	end

	def self.do(id)
		task = Task.find(id)
		$logger.debug "теперь по каждому серверу создаем TaskReport, который будет выполнять скрипт"
		(task = Task.find(id)).settings['serverids'].each do |sid|
			noda = TaskNode.with_active_state.find(sid)
			trep = TaskReport.new task: task, task_node: noda
			unless trep.save
				$logger.warn "Задача #{task.id} для #{user.name}@#{node.name} не шмагла. #{trep.errors.inspect}"
				next
			end
			trep.power!
		end
	end

	def mk_tmp
		self.tmpdir = "#{$cfg[:global][:cachedir]}/task-#{id}-#{ Time.now.strftime "%Y%m%d-%H%M%S" }"
		unless self.save
			$logger.error "Ошибка при записи задачи №#{id} в базу. #{self.errors.inspect}"
			return false
		end
		$logger.debug "Task #{id} mk_tmp #{tmpdir}"
		begin
			FileUtils.mkpath tmpdir
		rescue Errno::EACCES => e
			logger.fatal "Не могу создать папку #{tmpdir}. #{e}"
			return false
		end
	end
	def rm_tmp
		FileUtils.rm_r tmpdir if tmpdir.present?
	end
	def get_descr
		if settings.key?('descr') && ! settings['descr'].empty?
			self.descr = settings['descr']
		end
	end
	def parse_settings # пишем обработанный список файлов и ID серверов
		self.script = settings['script']
		settings['filelist'] ||= []
		settings['filelist'] << script
		(settings['filelist'] = settings['filelist'] | settings['files']) if settings.key?('files')
		self.settings['serverids'] = settings['servers'].collect do |name|
			TaskNode.with_active_state.id_name_uri(name).first.id
		end
	end
	def filelist
		settings['filelist']
	end
end
