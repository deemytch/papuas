require 'active_record'
require 'workflow'

class TaskReport < ActiveRecord::Base
	include Workflow
	workflow_column :status

	belongs_to :task
	belongs_to :task_node

	workflow do
		state :new do
		end
		state :active do
		end
		state :done
		state :failed
	end
end
