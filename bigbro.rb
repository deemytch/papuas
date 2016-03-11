#!/usr/bin/ruby
require_relative 'config.rb'
Config.start(:bigbro)

while true do
	# если вносятся изменения в базу, тогда ничего не делаем
	if Config.setlock?
		ServerAccount.with_dirty_state.each{|n| n.power! }
		ServerAccount.where(status: [:new, :active, :failed]).each{|src| src.check! }
		puts "источников #{SourceNode.with_active_state.count}\n" +
				"узлов #{TaskNode.with_active_state.count}"

		SourceNode.with_active_state.each{|src| src.load_tasks! }
		
		puts "задач #{Task.with_ready_state.count}"
		Task.where(:status => :ready).each{|task| task.doit! }
		Config.unlock!
	else
		puts "locked"
	end
	sleep $cfg[:global][:query_delay]
end
