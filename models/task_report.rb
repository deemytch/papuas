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
			event :power, :transition_to => :processing
			event :cancel, :transition_to => :fail
		end
		state :processing do
			event :allright, :transition_to => :done
			event :failed, :transition_to => :fail
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
		script = Pathname.new(task.script).basename # исходное имя может быть записано с путём
		soutn = "#{script}.stdout" # имена файлов для вывода
		serrn = "#{script}.stderr"
		sretn = "#{script}.retcode"
		dstdir = "#{node.path}/#{Pathname.new(task.tmpdir).basename}"
		node.login do |ssh|
			$logger.debug "TaskReport #{id} произвожу работу. файлы: #{`ls -l #{task.tmpdir}`}\t->#{node.uri}"
			ssh.scp.upload!(task.tmpdir, node.path, { recursive: true })
			$logger.debug "файлы скопированы. запускаю #{script}"
			o = ssh.exec! %{/bin/bash -lc 'cd #{dstdir} && touch #{soutn} #{serrn} #{sretn} && chmod +x #{script} && ./#{script} > #{soutn} 2>#{serrn} ; echo $? > #{sretn} ; pwd ; ls -lah' }
			o.force_encoding('utf-8')
			$logger.debug "#{script} отработал.\n#{o}\nзабираю результаты.\n#{dstdir}/#{soutn}\n#{dstdir}/#{serrn}\n#{dstdir}/#{sretn}"
			rep.stdout_log = ssh.scp.download! "#{dstdir}/#{soutn}"
			rep.stderr_log = ssh.scp.download! "#{dstdir}/#{serrn}"
			rep.retcode = (ssh.scp.download! "#{dstdir}/#{sretn}").chomp.to_i
			rep.save
		end
		rep.allright!
	end
end
