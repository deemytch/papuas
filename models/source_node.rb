class SourceNode < Server
  def check!
    users.each do |user|
      super.login_with(user){|ssh| ssh.exec! %{/usr/bin/bash -lc 'whoami && cd #{path}'}}
    end
  end
end
