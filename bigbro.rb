#!/usr/bin/ruby
require_relative 'config.rb'
Config.start(:bigbro)

while true do
	# переводим добавленные сервера в рабочий режим
	ServerAccount.with_dirty_state.each{|n| n.power! }
	$logger.info "источников #{SourceNode.with_active_state.count}, " +
			"узлов #{TaskNode.with_active_state.count}"

	# загружаем задачи, остальное сделает sidekiq
	SourceNode.with_active_state.each{|src| src.load_tasks! }
	$logger.info "загружено задач: #{Task.with_ready_state.count}"
	sleep $cfg[:global][:query_delay]
end
