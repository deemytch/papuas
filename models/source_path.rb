class SourcePath < Sequel::Model
  one_to_many :tasks
  one_to_many :users, :key => :node_id
  def validate
    super
    validates_presence :name
    validates_unique :name
  end
end
