require 'active_record'
require 'workflow'

class User < ActiveRecord::Base
	include Workflow  
	workflow_column :status

	has_many :users_servers
		has_many :servers, :through => :users_servers
		def source_nodes
			servers.where kindof: 'SourceNode'
		end
		def task_nodes
			servers.where kindof: 'TaskNode'
		end
	
	workflow do
		state :new do
			event :check_passed, :transition_to => :active
			event :check_failed, :transition_to => :failed
		end
		state :active do
			event :check_passed, :transition_to => :active
			event :check_failed, :transition_to => :failed
			event :modified, :transition_to => :new
		end
		state :failed do
			event :check_passed, :transition_to => :active
			event :check_failed, :transition_to => :failed
			event :modified, :transition_to => :new
		end
		state :deleted
	end
end
