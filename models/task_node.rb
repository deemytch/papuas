require 'active_record'
require 'workflow'

class TaskNode < Server
	has_many :tasks_reports
		has_many :tasks, :through => :tasks_reports

	def check!
		puts "#{name} check! :#{users.count}"
		users.each do |user|
			puts "Попытка зайти #{user.login}@#{host}:#{port}"
			login_with(user){|ssh| out = ssh.exec! %{/bin/bash -lc 'whoami'}}
			puts "> #{out}"
		end
		self.checked_ok!
	end
end
