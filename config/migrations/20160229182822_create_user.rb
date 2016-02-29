class CreateUser < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name, null: false, index: { unique: true }
  		t.string :login, index: true
  		t.string :key
  		t.string :key_type
  		t.column :status, "enum('new', 'active', 'failed', 'deleted')", :default => 'new', null: false, index: true
      t.timestamps null: false
    end
    add_index :users, [:login, :key], unique: true
  end
end
