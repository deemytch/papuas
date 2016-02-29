require 'active_record'
require 'workflow'

class Task < ActiveRecord::Base
	include Workflow
	workflow_column :status

	belongs_to :source_node
	has_many	:task_reports
		has_many :task_nodes, :through => :task_reports
	
	workflow do
		state :new do
		end
		state :active do
		end
		state :done
		state :deleted
	end

end
