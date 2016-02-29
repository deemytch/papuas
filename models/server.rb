require 'workflow'
require 'active_record'

class Server < ActiveRecord::Base
	self.inheritance_column = 'kindof'
	include Workflow
	workflow_column :status

	has_many :task_reports
	has_many :users_servers
		has_many :users, :through => :users_servers

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
		data[:key] = key if user.key
		data[:password] = password if user.password
		data[:username] = user.login unless user.nil?
		Net::SSH.start(host, data){ yield}
	end
end
