#!/usr/bin/env ruby
at_exit{
	exit! $exitcode
}

options = {}
if ARGV.empty?
	puts `#{$0}  --help`
	exit
end
# настройки
require_relative './config.rb'
Config.start
# параметры командной строки
options = Parser.options
$logger.debug "команды: #{options.inspect}"
# выполнить всё веленное
Executor.add_changes!(options)
