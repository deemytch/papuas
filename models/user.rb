class User < Sequel::Model
  set_schema do
    primary_key :id
    String :name, unique: true, null: false
    String :login,            null: false, index: true
    String :key,              null: false
    String :key_type,         null: false
    column :status, "enum('new', 'active', 'failed', 'deleted')", :default => 'new', null: false, index: true
    DateTime :created_at, null: false
    DateTime :updated_at, null: false
  end
  many_to_many :servers, :join_table => :users_servers
  
  def validate
    validates_unique [:login, :key]
  end

end
