require 'workflow'
require 'active_record'

class ServerAccount < ActiveRecord::Base
	self.inheritance_column = 'kindof'
	include Workflow
	workflow_column :status

	has_many :tasks, :inverse_of => :server_account
	has_many :task_reports, :inverse_of => :server_account
	before_validation :name_and_host
	validates :name, presence: true, uniqueness: true
	validate :can_login?, if: ->{ (%w[host port user path] & self.changes.keys).any? }
	after_create { passed! }	
	scope :id_name, ->(s){ where "id = ? OR name = ?", s, s }
	scope :id_name_uri, ->(s){
		if s =~ /@?.*:|\w@\w/
			where s.to_ssh_uri
		else
			id_name(s)
		end
	}

	workflow do
		state :new do
			event :passed, :transition_to => :dirty
			event :failed, :transition_to => :deleted
		end
		state :dirty do # в активный режим переводятся когда нет никакой активности
			event :power, :transition_to => :active
			event :power_off, :transition_to => :off
		end
		state :active do
			event :passed, :transition_to => :active
			event :failed, :transition_to => :fail
			event :power_off, :transition_to => :off
			event :load_tasks, :transition_to => :processing, meta: { taskmanager: false }
		end
		state :processing do
			event :passed, :transition_to => :active
			event :process_done, :transition_to => :active
			event :process_fail, :transition_to => :fail
		end
		state :off do
			event :passed, :transition_to => :active
			event :failed, :transition_to => :failed
		end
		state :fail do
			event :passed, :transition_to => :dirty
			event :zap, :transition_to => :deleted
		end
		state :deleted
		on_transition do |f,t,e, *ea|
			$logger.debug "#{kindof}:##{id}.#{name} переход #{f} -> #{t} (#{ea.inspect})"
		end
	end

	def login(&block)
		$logger.debug "ServerAccount##{id}.login"
		Net::SSH.start(host, user, sshparams){|ssh| yield(ssh) }
	end

	def can_login?
		$logger.debug "ServerAccount.can_login? #{user}@#{host}"
		cmdout = Net::SSH.start(host, user, sshparams) do |ssh|
			ssh.exec! %{/bin/bash -lc 'whoami && cd "#{path}" && pwd ; echo $?'}
		end
		$logger.debug cmdout
		cmdout.force_encoding(Encoding::UTF_8)
		if cmdout.split("\n").last.chomp.to_i != 0
			errors.add :path, "Путь #{path} на сервере не найден.\n#{cmdout}"
			return false
		end
		return true
	# rescue SocketError => e
	# 	errors.add :host, "Не найден хост, #{e}"
	# 	return false
	# rescue Errno::ECONNREFUSED => e
	# 	errors.add :port, "Ошибка подключения. Порт правильный? #{e}"
	# 	return false
   # rescue Net::SSH::AuthenticationFailed => e
   # 	errors.add :user, "Ошибка входа, #{e}"
   # 	return false
	end
	
	def sftplogin(&block)
		$logger.debug "SFTP вход на ServerAccount #{name}"
		Net::SFTP.start(host, user, sshparams){|sftp| yield(sftp) }
	end

	def check!
		passed! if can_login?
	end

	def uri_or_name=(s)
		if s =~ /^(\w+@)?.+:(\d+)?|^\w+@.+/
			self.uri = s
		else
			self.name = s
		end
	end

	def uri=(a)
		u = URI(a =~ /^ssh:/ ? a : "ssh://#{a}")
		self.assign_attributes({host: u.host, port: u.port, user: u.user, path: u.path})
		$logger.debug "Server.uri=#{a} -> #{user}@#{host}:#{port}#{path}"
	end

	def uri
		"ssh://#{user}@#{host}:#{port}#{path}"
	end

	def sshparams
		data = { timeout: $cfg[:global][:timeout], :auth_methods=>%w[publickey hostbased] }
		data[:port] = port if port
		data[:key] = key if key
		return data
	end

	private
	def name_and_host
		self.host = name if host.nil? || host.empty?
		if name.nil? || name.empty?
			self.name = user ? "#{user}@" : ''
			self.name += host
		end
	end
end
