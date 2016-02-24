class TaskNode < Server
  one_to_many :tasks
#  many_to_many :users, :join_table => :servers_users, :left_key => :server_id
  def check!
    users.each do |user|
      login_with(user){|ssh| ssh.exec! %{/bin/bash -lc 'whoami'}}
    end
  end
end
