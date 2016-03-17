class CreateServerAccount < ActiveRecord::Migration
  def change
    create_table :server_accounts do |t|
    	t.string    :kindof,    null: false, index: true
      t.string    :name,      null: false, unique: true
      t.string    :host,      null: false, index: true
      t.integer   :port
      t.string    :descr
      t.string    :user, index: true
      t.text      :key
      t.string    :key_type
      t.string    :path
      t.string    :realname, index: true
      t.string    :status, :default => 'new', null: false, index: true
      
      t.timestamps null: false
    end
    add_index :server_accounts, [:name, :user, :host, :port, :path], unique: true, name: 'index_account_uri'
  end
end
