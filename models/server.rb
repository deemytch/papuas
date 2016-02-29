require 'workflow'

class Server < Sequel::Model
  include Workflow
  
  plugin :single_table_inheritance, :kindof
  set_schema do
    primary_key :id
    String :kindof, null: false, index: true
    String  :name, null: false, unique: true
    String  :host, null: false
    Integer  :port, null: false, default: 22
    String   :path
    String :descr
    column   :status, "enum('new', 'active', 'failed', 'deleted')", :default => 'new', null: false, index: true
    DateTime :created_at, null: false
    DateTime :updated_at, null: false
  end
  one_to_many :task_reports
  many_to_many :users, :join_table => :servers_users
  many_to_many :tasks, :join_table => :tasks_reports
	workflow do
		state :new do
			event :checked_ok, :transition_to => :active
			event :ckecked_bad, :transition_to => :failed
		end
		state :active do
			event :checked_ok, :transition_to => :active
			event :ckecked_bad, :transition_to => :failed
		end
		state :failed do
			event :checked_ok, :transition_to => :active
			event :ckecked_bad, :transition_to => :failed
		end
		state :deleted
		on_transition do |f,t,e, *ea|
			puts "#{kindof}:#{name} переход #{f} -> #{t}"
		end
	end
  def login_with(user, &block)
		data = {}
		data[:key] = key if key
		data[:password] = password if password
		data[:username] = user.login unless user.nil?
    Net::SSH.start(host, data){ yield}
  end
end
