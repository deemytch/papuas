require 'active_record'
require 'workflow'
require 'sidekiq'

class TaskReport < ActiveRecord::Base
	include Workflow
	include Sidekiq::Worker
	sidekiq_options :retry => false, :backtrace => true

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
	def on_processing_entry(new_state, event, *args)
		self.class.do(self.id)
	end
	def self.do(id)
		rep = TaskReport.find(id)
		task = rep.task
		node = rep.task_node
		dstdir = "#{node.path}/#{Pathname.new(task.tmpdir).basename}"
		node.login do |ssh|
			$logger.debug "TaskReport #{id} произвожу работу. файлы: #{`ls -l #{task.tmpdir}`}"
			ssh.scp.upload(task.tmpdir, node.path, { recursive: true })
			ssh.exec! %{/bin/bash -lc 'cd #{dstdir} && chmod +x #{task.script}' && ./#{task.script} > #{task.script}.stdout 2>#{task.script}.stderr ; echo $? > #{task.script}.retcode }
			rep.stdout_log = ssh.scp.download! "#{dstdir}/#{task.script}.stdout"
			rep.stderr_log = ssh.scp.download! "#{dstdir}/#{task.script}.stderr"
			rep.retcode = (ssh.scp.download! "#{dstdir}/#{task.script}.retcode").chomp.to_i
			rep.save
		end
		rep.allright!
	end
end
