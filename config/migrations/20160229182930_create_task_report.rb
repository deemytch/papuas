class CreateTaskReport < ActiveRecord::Migration
	def change
		create_table :task_reports do |t|
			t.references :task, null: false, index: true, foreign_key: true
			t.references :task_node, null: false, index: true
			t.integer	 :retcode
			t.string		:stdout_log
			t.string		:stderr_log
			t.datetime	:started_at
			t.datetime	:stopped_at
			t.column		:status, "enum('new', 'active', 'done', 'failed')", :default => 'new', null: false, index: true

			t.timestamps null: false
		end
    	add_foreign_key :task_reports, :servers, :column => :task_node_id
		add_index :task_reports, [:task_id, :task_node_id]
	end
end