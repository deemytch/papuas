#!/usr/bin/ruby
require_relative 'config.rb'
Config.start(:bogbro)

while true do
	# Сначала пингуем наличие серверов и ищем есть ли новые задачи
	puts "источников #{SourceNode.with_active_state.count}"
	SourceNode.where(status: [:new, :active, :failed]).each{|src| src.check! }

	puts "узлов #{TaskNode.with_active_state.count}"
	TaskNode.where(status: [:new, :active, :failed]).each{|n| n.check! }

	SourceNode.with_active_state.each{|src| src.load_tasks! }
	
	# Теперь можно и позапускать всё
	puts "задач #{Task.with_new_state.count}"
	Task.where(:status => :new).each{|task| task.doit! }
	sleep $cfg[:global][:query_delay]
end
