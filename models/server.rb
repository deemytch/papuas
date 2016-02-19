class Server < Sequel::Model
  plugin :single_table_inheritance, :kindof
  set_schema do
    primary_key :id
    column :kindof, "enum('node', 'source')", null: false, index: true
    String   :name,           null: false, unique: true
    Integer  :addr,           null: false
    Integer  :port, null: false, default: 22
    String   :path
    column   :status, "enum('new', 'active', 'failed', 'deleted')", :default => 'new', null: false, index: true
    DateTime :created_at,     null: false
    DateTime :updated_at,     null: false
  end
  one_to_many :task_reports
  many_to_many :users, :join_table => :servers_users
  many_to_many :tasks, :join_table => :tasks_reports

  def validate
    super
    validates_presence :name
    validates_unique :name
  end
=begin
  варианты uri:
  [{login[:keyfile],...}@](shorthost|host):[port]
  
=end
  def uri=(uri)  
    uri =~ /\A(([^@]+)@)?([^:]+):(\d+)?(.+)\z/
    users = $2
    self.host = $3
    self.port = $4 || 22
    self.path = $5
    
  end

end
