require 'active_record'
require 'workflow'
require 'fileutils'
require 'net/sftp'
=begin
 Представление файла настроек задачи в базе.
 На входе - файл yml
 Проверяет наличие исходных файлов и записывает
 объекты TaskReport по количеству узлов, на которых выполняется данная задача
=end
class Task < ActiveRecord::Base
	serialize :settings
	include Workflow
	workflow_column :status

	belongs_to :source_node
	has_many	:task_reports, :dependent => :destroy
		has_many :task_nodes, :through => :task_reports
	
	validate :yamlsettings # побочные эффекты!
	before_destroy :rm_tmp

	workflow do
		state :new do
			event :check_passed, :transition_to => :ready
			event :check_failed, :transition_to => :deleted
		end
		state :ready do
			event :started, :transition_to => :processing
			event :check_failed, :transition_to => :new
		end
		state :processing do
			event :all_right, :transition_to => :done
			event :task_failed, :transition_to => :failed
		end
		state :failed do
			event :restart, :transition_to => :ready
			event :remove, :transition_to => :deleted
		end
		state :done
		state :deleted
	end

	def yamlsettings
		sshdata = { timeout: $cfg[:global][:timeout], :auth_methods=>%w[publickey hostbased] }
		errors.add :settings, 'Не хватает данных для задачи' if ! settings.key?('server') || ! settings.key?('script') || settings['server'].empty?
		settings['servers'].each do |srv, u|
			if (noda = Server.with_active_state.find_by(name: srv)).nil? ||
				(user = noda.users.with_active_state.find_by(name: u)).nil? then
					errors.add :settings, "Невозможно использовать #{u}@#{srv}"
			end
		end
		# мало ли какие файлы там надо скопировать, на всякий случай не буду их тащить в базу
		Net::SCP.start(source_node.host, source_node.users.last.login, sshdata) do |scp|
			self.script = scp.download "#{source_node.path}/#{settings['script']}"
			if settings.key?('files')
				self.data ||= Dir.mktmpdir "task-#{id}-", $cfg[:global][:tmpdir] # может уже всё есть?
				settings['files'].each do |fdata|
					scp.download "#{source_node.path}/#{fdata}", data
				end
			end
			scp.loop!
		end
		# теперь по каждому серверу создаем TaskReport, который будет выполнять скрипт
		settings['servers'].each do |srv, u|
			noda = Server.with_active_state.find_by(name: srv)
			user = noda.users.with_active_state.find_by(name: u)
			tr = TaskReport.create task: self, task_node: noda, user: user
			if tr.nil?
				$logger.warn "Задача #{descr} для #{user.name}@#{node.name} не шмагла. Что это было?"
				next
			end
		end
	rescue SocketError => e
		errors.add :source_node_id, "Ошибка сети #{e}"
	rescue Net::SSH::AuthenticationFailed => e
		errors.add :source_node_id, "Ошибка сети #{e}"
	rescue Net::SCP::Error => e
		errors.add :settings, "Обнаружено наличие отсутствия доступа к файлу #{e}. Проверь там чего-нибудь."
	end
	# для параллельности запускаем выполнение скрипта отсюда, а не из TaskReport
	# и пишем TaskReports
	def go!
		sshdata = { timeout: $cfg[:global][:timeout], :auth_methods=>%w[publickey hostbased] }
		scriptdir = Pathname.new(data).basename
		scriptname = Pathname.new(settings['script']).basename
		reports = task_reports
		whenstop = Proc.new {|s| s.busy? }
		# копируем туда всё
		reports.each do |t|
			t.sshsession = Net::SSH.start(t.task_node.host, t.user.login || '', sshdata)
			t.scpupload = t.sshsession.scp.upload(data, '/tmp', { recursive: true })
		end
		reports.each{|t| t.scpupload.wait }
		# теперь запускаем скрипт ловим stdout и stderr
		reports.each do |t|
			t.sshsession.exec %{ /bin/bash -lc 'cd /tmp/#{dstdir} && chmod +x #{scriptname}' && ./#{scriptname} > #{scriptname}.stdout 2>#{scriptname}.stderr ; echo $? > #{scriptname}.retcode }
		end
		# ждём окончания, забираем всё обратно
		reports.each{|t| t.sshsession.loop! }
		reports.each do |t|
			t.stdout_log = t.sshsession.scp.download %{/tmp/#{dstdir}/#{scriptname}.stdout }
			t.stderr_log = t.sshsession.scp.download %{/tmp/#{dstdir}/#{scriptname}.stderr }
			t.retcode = t.sshsession.scp.download %{/tmp/#{dstdir}/#{scriptname}.retcode }
			t.wait
			t.save!
		end
	end

	def rm_tmp
		FileUtils.rm_r data if data.present?
	end
end
