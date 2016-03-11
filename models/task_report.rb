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
			event :passed, :transition_to => :ready
			event :failed, :transition_to => :fail
		end
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
