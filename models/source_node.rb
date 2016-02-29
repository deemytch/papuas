class SourceNode < Server
	has_many :tasks
	has_many :task_reports, :through => :tasks

	def check!
   	users.each do |user|
      	super.login_with(user){|ssh| ssh.exec! %{/bin/bash -lc 'whoami && cd #{path}'}}
   	end
	end
end
