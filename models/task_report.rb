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
	def on_processing_entry()
		self.perform_async
	end
	def perform(id)
		rep = TaskReport.find(id)
		dstdir = "#{rep.task_node.path}/#{task_node.path}"
		Net::SSH.login do |ssh|
			ssh.scp.upload(rep.task.tmpdir, task_node.path, { recursive: true })
			ssh.exec! %{/bin/bash -lc 'cd #{dstdir} && chmod +x #{scriptname}' && ./#{scriptname} > #{scriptname}.stdout 2>#{scriptname}.stderr ; echo $? > #{scriptname}.retcode }
			rep.stdout_log = ssh.scp.download %{#{dstdir}/#{scriptname}.stdout }
			rep.stderr_log = ssh.scp.download %{#{dstdir}/#{scriptname}.stderr }
			rep.retcode = (ssh.scp.download %{#{dstdir}/#{scriptname}.retcode }).chomp.to_i
			rep.save
		end
		rep.allright!
	end
	
end
