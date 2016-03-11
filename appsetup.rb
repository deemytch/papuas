#!/usr/bin/env ruby
=begin
	1. Проверить наличие базы
	2. Прочитать параметры командной строки
	3. Проверить непротиворечивость параметров и базы
	4. Записать всё в базу с флагом dirty
=end
options = {}
if ARGV.empty?
	puts `#{$0}  --help`
	exit
end
require_relative './config.rb'
Config.start
Config.set_gad
options = Parser.options
$logger.debug "команды: #{options.inspect}"
Executor.add_changes!(options)
# Executor.perform_async
