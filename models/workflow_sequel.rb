module Workflow
	def load_workflow_state
		self.status
	end
	def persist_workflow_state(newval)
		self.status = newval
		save
	end
end
