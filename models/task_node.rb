require 'active_record'
require 'workflow'

class TaskNode < ServerAccount
	has_many :tasks_reports
		has_many :tasks, :through => :tasks_reports

end
