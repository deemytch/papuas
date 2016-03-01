require 'workflow'
require 'active_record'

class Server < ActiveRecord::Base
	self.inheritance_column = 'kindof'
	include Workflow
	workflow_column :status

	has_many :task_reports, :dependent => :destroy
	has_many :users_servers, :dependent => :destroy
		has_many :users, :through => :users_servers, :dependent => :destroy
	validates :name, uniqueness: true
	before_validation :name_and_host
	before_destroy :remove_habtm

	workflow do
		state :new do
			event :checked_ok, :transition_to => :active
			event :checked_bad, :transition_to => :failed
		end
		state :active do
			event :checked_ok, :transition_to => :active
			event :checked_bad, :transition_to => :failed
		end
		state :failed do
			event :checked_ok, :transition_to => :active
			event :checked_bad, :transition_to => :failed
		end
		state :deleted
		on_transition do |f,t,e, *ea|
			puts "#{kindof}:#{name} переход #{f} -> #{t}"
		end
	end
	def login_with(user = nil, &block)
		data = { timeout: $cfg[:global][:timeout] }
		if user.present?
			data[:key] = key if user.key
			data[:username] = user.login unless user.login
		end
		Net::SSH.start(host, data){ yield}
	rescue Net::SSH::ConnectionTimeout
		self.checked_bad!
	end

	private
	def remove_habtm
		puts "Server.remove_habtm"
		users_servers.all.each{|us| us.destroy }
	end
	def name_and_host
		self.host = name if host.nil?
		self.name = host if name.nil?
	end
end
