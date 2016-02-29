class TaskNode < Server
  one_to_many :tasks
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
