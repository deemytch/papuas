class Node < Sequel::Model
  one_to_many :task_reports
  one_to_many :users
  many_to_many :tasks, :join_table => :task_reports
  def validate
    super
    validates_presence :name
    validates_unique :name
  end
end
