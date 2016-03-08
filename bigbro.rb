#!/usr/bin/ruby
require_relative 'config.rb'
Config.start(:bogbro)

while true do
	Server.where(status: [:new, :active, :failed]).each{|src| src.check! }
	puts "источников #{SourceNode.with_active_state.count}\n" +
			"узлов #{TaskNode.with_active_state.count}"

	SourceNode.with_active_state.each{|src| src.load_tasks! }
	
	puts "задач #{Task.with_new_state.count}"
	Task.where(:status => :new).each{|task| task.doit! }
	sleep $cfg[:global][:query_delay]
end
