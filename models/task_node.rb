require 'active_record'
require 'workflow'

class TaskNode < Server
	has_many :tasks_reports
		has_many :tasks, :through => :tasks_reports
	validate :check!

	def check!
		$logger.debug "#{name} check! :#{users.count}"
		users.each do |user|
			$logger.debug "Попытка зайти #{user.login}@#{host}:#{port}"
			login_with(user){|ssh| out = ssh.exec! %{/bin/bash -lc 'whoami'}}
			$logger.debug "> #{out}"
		end
		if self.id.nil?
			self.status = :active
		else
			checked_ok!
		end
	end
end
