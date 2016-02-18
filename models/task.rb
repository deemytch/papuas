class Task < Sequel::Model
  many_to_one :source_path
  one_to_many :task_reports
end
