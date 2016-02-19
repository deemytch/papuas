class TaskReport < Sequel::Model
   set_schema do
    primary_key :id
    Integer :task_id, null: false, index: true
      foreign_key [:task_id], :tasks
    Integer :task_node_id, null: false, index: true
      foreign_key [:task_node_id], :servers # kindof source
    Integer   :retcode
    String    :stdout_log
    String    :stderr_log
    DateTime  :started_at
    DateTime  :stopped_at
    column    :status, "enum('new', 'active', 'done', 'failed')", :default => 'new', null: false, index: true
    DateTime :created_at, null: false
    DateTime :updated_at, null: false
    index [:task_id, :task_node_id], index: true
  end
  many_to_one :task
  many_to_one :node
end
