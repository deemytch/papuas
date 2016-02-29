class SourceNode < Server
	has_many :tasks
	has_many :task_reports, :through => :tasks, :dependent => :destroy

	def check!
		user = users.last
		$logger.debug "#{name} check! :#{user.try :name}"
		$logger.debug "Попытка зайти #{user.try :login}@#{host}:#{port}"
   	# логинимся для проверки и копируем туда-оттуда файлик
   	login_with(users.last){|ssh| ssh.exec! %{/bin/bash -lc 'whoami && cd #{path}'}}
   	
   	checked_ok!
	end
end
