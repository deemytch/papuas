require 'workflow'
require 'active_record'

class ServerAccount < ActiveRecord::Base
	self.inheritance_column = 'kindof'
	include Workflow
	workflow_column :status

	has_many :tasks, :inverse_of => :server_account
	has_many :task_reports, :inverse_of => :server_account

	validates :name, presence: true, uniqueness: true
	before_validation :name_and_host
	

	workflow do
		state :new do
			event :passed, :transition_to => :dirty
			event :failed, :transition_to => :deleted
		end
		state :dirty do # в активный режим переводятся когда нет никакой активности
			event :power, :transition_to => :active
		end
		state :active do
			event :passed, :transition_to => :active
			event :failed, :transition_to => :off
		end
		state :off do
			event :passed, :transition_to => :active
			event :failed, :transition_to => :failed
		end
		state :fail
		state :deleted
		on_transition do |f,t,e, *ea|
			$logger.debug "#{kindof}:##{id}.#{name} переход #{f} -> #{t}"
		end
	end
	def login(&block)
		$logger.debug "ServerAccount##{id}.login"
		data = { timeout: $cfg[:global][:timeout], :auth_methods=>%w[publickey hostbased] }
		data.merge!({ port: port }) if port
		data.merge!({ key: key }) if key
		$logger.debug "\t\t для входа: #{data.inspect};"
		Net::SSH.start(host, user, data){|ssh| yield(ssh) }
	rescue StandardError => e
		$logger.warn "#{e}"
		failed!
	end
	def check!
		$logger.debug "ServerAccount##{id}.check!"
		cmdout = ''
		login{|ssh|
			$logger.debug "Начали"
			cmdout = ssh.exec!((path.present? && ! path.empty?) ?
					%{/bin/bash -lc 'whoami && cd "#{path}" && pwd'} : %{/bin/bash -lc 'whoami'})
		}
		passed!
		return cmdout
   rescue Net::SSH::AuthenticationFailed => e
   	$logger.warn "Ошибка входа #{uri}"
		failed!
	end

	def uri=(a)
		u = URI(a)
		self.assign_attributes({host: u.host, port: u.port, user: u.user, path: u.path})
		$logger.debug "Server.uri=#{a} -> #{user}@#{host}:#{port}/#{path}"
	end

	def uri
		"ssh://#{user}@#{host}:#{port}/#{path}"
	end

	scope :host_or_uri, Proc.new {|s|
		if s =~ /@?.*:/ # uri
			data =  URI('ssh://' + s).instance_values.select{|k,v| v && ! v.empty? && %w[user host port path].include?(k) }
			$logger.debug "with_login_or_name: #{s} -> #{data.inspect}"
			where data
		else
			where "host = ? OR name = ?", s, s
		end
	}

	private
	def name_and_host
		self.host = name if host.nil? || host.empty?
		self.name = host if name.nil? || name.empty?
	end
end
