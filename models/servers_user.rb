class ServersUser < Sequel::Model
  set_schema do
    primary_key :id
    Integer :server_id, null: false # polymorphic
    String :server_type, null: false
      index [:server_id, :server_type]
    Integer :user_id, null: false, index: true
      foreign_key [:user_id], :users
      index [:server_id, :server_type, :user_id], unique: true
  end
end
