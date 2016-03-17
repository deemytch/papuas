require 'logger'

# при ругани меняем код выхода глобально
class Logger
	alias_method :add_without_exit_code, :add
	def add(severity, message = nil, progname = nil)
		if severity == FATAL || severity == ERROR
			$exitcode ||= 0
			$exitcode += 1
		end
		self.add_without_exit_code severity, message, progname
	end
end
