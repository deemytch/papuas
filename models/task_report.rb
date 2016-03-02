require 'active_record'
require 'workflow'

class TaskReport < ActiveRecord::Base
	include Workflow
	workflow_column :status

	belongs_to :task
	belongs_to :task_node

	validates :task, presence: true
	validates :task_node, presence: true

	workflow do
		state :new do
			event :check_passed, :transition_to => :ready
			event :check_failed, :transition_to => :failed
		end
		state :ready do
			event :letsgo, :transition_to => :running
			event :cancel, :transition_to => :failed
		end
		state :running do
			event :allright, :transition_to => :done
			event :crashed, :transition_to => :failed
		end
		state :done
		state :failed
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
end
