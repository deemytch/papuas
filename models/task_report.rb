require 'active_record'
require 'workflow'
require 'sidekiq'

class TaskReport < ActiveRecord::Base
	include Workflow
	include Sidekiq::Worker

	workflow_column :status

	belongs_to :task
	belongs_to :task_node

	validates :task, presence: true
	validates :task_node, presence: true

	workflow do
		state :ready do
			event :power, :transition_to => :processing, meta: { instigator: self.class }
			event :cancel, :transition_to => :fail, meta: { instigator: self.class }
		end
		state :processing do
			event :allright, :transition_to => :done, meta: { instigator: self.class }
			event :failed, :transition_to => :fail, meta: { instigator: self.class }
		end
		state :done
		state :fail

	end
# временные аттрибуты
	def sshsession=(sess)
		@sshsession = sess
	end
	def sshsession
		@sshsession
	end

	def scpupload=(upl)
		@scpupload = upl
	end
	def scpupload
		@scpupload
	end

	def perform
		started!
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
	rescue StandardError => e
		$logger.fatal "При выполнении задачи произошла ошибка парламентёра.\n#{e}"
		script_failed!
	end

end
