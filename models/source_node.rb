class SourceNode < Server
	has_many :tasks
	has_many :task_reports, :through => :tasks, :dependent => :destroy
	after_save :check!
end
