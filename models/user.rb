require 'workflow'

class User < Sequel::Model
  include Workflow  
  set_schema do
    primary_key :id
    String :name, unique: true, null: false
    String :login,            null: false, index: true
    String :key,              null: false
    String :key_type,         null: false
    index [:login, :key], unique: true
    column :status, "enum('new', 'active', 'failed', 'deleted')", :default => 'new', null: false, index: true
    DateTime :created_at, null: false
    DateTime :updated_at, null: false
  end
  many_to_many :servers, :join_table => :servers_users
  many_to_many :source_nodes, :join_table => :servers_users, :right_key => :server_id, :class => :SourceNode, graph_conditions: { kindof: 'SourceNode'}
  many_to_many :task_nodes, :join_table => :servers_users, :right_key => :server_id, :class => :TaskNode, graph_conditions: { kindof: 'TaskNode'}
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
