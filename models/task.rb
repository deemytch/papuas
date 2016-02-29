require 'workflow'

class Task < Sequel::Model
  include Workflow
  
  set_schema do
    primary_key :id
    Integer :source_node_id, null: false, index: true
      foreign_key [:source_node_id], :servers # kindof node
    String   :settings,       null: false
    String   :script,         null: false
    String   :data
    String   :descr
    DateTime :started_at
    DateTime :stopped_at
    column   :status, "enum('new', 'active', 'done', 'failed')", :default => 'new', null: false, index: true
    DateTime :created_at, null: false
    DateTime :updated_at, null: false
  end
  
  many_to_one :source_node
  one_to_many :task_reports
  many_to_many :task_nodes, :join_table => :task_reports
	workflow do
		state :new do
		end
		state :active do
		end
		state :done
		state :deleted
	end

end
