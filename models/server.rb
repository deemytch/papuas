class Server < Sequel::Model
  plugin :single_table_inheritance, :kindof
  set_schema do
    primary_key :id
    String :kindof, null: false, index: true
    String  :name, null: false, unique: true
    String  :host, null: false
    Integer  :port, null: false, default: 22
    String   :path
    String :descr
    column   :status, "enum('new', 'active', 'failed', 'deleted')", :default => 'new', null: false, index: true
    DateTime :created_at, null: false
    DateTime :updated_at, null: false
  end
  one_to_many :task_reports
  many_to_many :users, :join_table => :servers_users
  many_to_many :tasks, :join_table => :tasks_reports
  
  def login_with(user, &block)
    # Net::SSH.start(host, user.login, key: key)
    Net::SSH.start(host, user.login){ yield }
  end
end
