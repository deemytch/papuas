#!/usr/bin/env ruby
require 'logger'
require 'optionparser'
require_relative 'config.rb'
Config.start(:bigbro)

runmode = 'single'
run_descr = { 'single' => "Однократный запуск без менеджера задач",
	'tasks' => 'Однократная загрузка задач в менеджер',
	'prod' => 'production' }
verbose = Logger::INFO

OptionParser.new do |parser|
	parser.on('-j [mode]', '--multi [single|tasks|prod]', String,
		"Выполнить задачи:\n\t\t\t\t\tsingle: один раз (по умолчанию),\n\t\t\t\t\tmulti: один раз на менеджере задач\n\t\t\t\t\tprod: в цикле на менеджере задач" +
		 "\n\t\t\t\t\t(настройки в config/sidekiq.yml)") do |mode|
		runmode = mode if mode =~ /^(single|multi|prod)$/
	end
	parser.on('-v [level]', '--verbose [debug|notice|warn|error|fatal]', String,
		'Разговорчивый режим, чтобы усилить - добавь ещё "v"') do |level|
		puts "Выбран режим разговорчивости #{Config.verbosity.find_index(level)}"
		if level =~ /^(debug|notice|warn|error|fatal)$/
			verbose = Config.verbosity.find_index(level) if Config.verbosity.include?(level)
		else
			verbose -= 1
			verbose = 0 if verbose < 0
		end
		Config.set_gad verbose
	end
	parser.on('-h', '--help', 'Справка'){ puts parser; exit }
end.parse!

puts "выбран: #{run_descr[runmode]}"

# СДЕЛАТЬ
# tm (taskmanager) запускать задачи в консоли (false) или на sidekiq (true)
def handjob(tm = false) 
	# переводим добавленные сервера в рабочий режим
	ServerAccount.with_dirty_state.each{|n| n.power! }
	$logger.info "источников #{SourceNode.with_active_state.count}, " +
			"узлов #{TaskNode.with_active_state.count}"

	# загружаем задачи, остальное сделает sidekiq или не sidekiq
	SourceNode.with_active_state.each{|src| src.load_tasks!(meta: { taskmanager: tm }) }
	$logger.info "загружено задач: #{Task.with_processing_state.count}"
end

while true do
	handjob
	break if runmode == 'single'
	sleep $cfg[:global][:query_delay]
end
