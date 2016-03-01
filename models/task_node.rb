require 'active_record'
require 'workflow'

class TaskNode < Server
	has_many :tasks_reports
		has_many :tasks, :through => :tasks_reports
	after_save :check!
end
