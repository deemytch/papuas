require 'active_record'
require 'workflow'

class User < ActiveRecord::Base
	include Workflow  
	workflow_column :status
	before_validation :set_login
	before_destroy :remove_habtm
	validate :name_or_login
	validate :unique_user

	has_many :users_servers, :dependent => :destroy
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

	private
	def name_or_login
		errors.add :name, 'Имя или логин должны быть' if (login.nil? || login.empty?) && (name.nil? || name.empty?)
	end
	def unique_user
		errors.add :name, "Имя, логин и ключ вместе не должны повторяться" if User.where(name: name, login: login, key: key, id: id).count > 1
	end
	def set_login
		self.name = login if name.nil? || name.empty?
		self.login = name if login.nil? || login.empty?
	end
	def remove_habtm
		puts "User.remove_habtm"
		users_servers.all.each{|us| us.destroy }
	end
end
