class TaskReport < Sequel::Model
  many_to_one :task
  many_to_one :node
end
