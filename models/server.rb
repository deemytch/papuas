require 'workflow'
require 'active_record'

class Server < ActiveRecord::Base
	self.inheritance_column = 'kindof'
	include Workflow
	workflow_column :status

	has_many :task_reports, :dependent => :destroy
	has_many :users_servers, :dependent => :destroy
		has_many :users, :through => :users_servers, :dependent => :destroy
	validates :name, presence: true, uniqueness: true
	before_validation :name_and_host
	before_destroy :remove_habtm

	workflow do
		state :new do
			event :checked_ok, :transition_to => :active
			event :checked_bad, :transition_to => :deleted
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
		data = { timeout: $cfg[:global][:timeout], :auth_methods=>%w[publickey hostbased] }
		if user.present?
#			data[:key] = user.key if user.key
			data[:user] = user.login unless user.login
		end
		Net::SSH.start(host, user.try(:login), data){ yield }
	end
	def me_not_valid!
		if id.nil?
			errors.add :host, "Невозможно зайти на #{host}. Запись отклонена"
		else
			checked_bad!
		end
	end
	def testlogin(u = nil)
		data = { timeout: $cfg[:global][:timeout], :auth_methods=>%w[publickey hostbased] }
		cmdout = ''
		Net::SSH.start(host, u.try(:login), data){|ssh|
			cmdout = ssh.exec!((path.present? && ! path.empty?) ?
					%{/bin/bash -lc 'whoami && cd "#{path}"'} : %{/bin/bash -lc 'whoami'})
		}
		return cmdout
   rescue Net::SSH::AuthenticationFailed => e
   	$logger.warn "Ошибка входа #{user.try :name} на #{name}"
   	if u.present?
   		u.check_failed!
   	else
   		checked_bad!
   	end
	end
	def check!(creds = self.users)
   	# логинимся для проверки и копируем туда-оттуда файлик
   	cmdout = ''
		if creds.nil? || creds.empty?
			cmdout = testlogin
			checked_ok!
			$logger.debug "> #{cmdout}"
		else
			creds = [creds] if creds.is_a? User
			creds.each do |u|
				testlogin(u)
				u.check_passed!
	   		checked_ok!
	   		$logger.debug "> #{cmdout}"
	   	end
   	end
	rescue Net::SSH::ConnectionTimeout => e
		checked_bad!
	end

	private
	def remove_habtm
		puts "Server.remove_habtm"
		users_servers.all.each{|us| us.destroy }
	end
	def name_and_host
		self.host = name if host.nil? || host.empty?
		self.name = host if name.nil? || name.empty?
	end
end
