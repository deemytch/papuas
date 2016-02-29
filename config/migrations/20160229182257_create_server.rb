class CreateServer < ActiveRecord::Migration
  def change
    create_table :servers do |t|
    	t.string    :kindof,    null: false, index: true
      t.string    :name,      null: false, unique: true
      t.string    :host,      null: false
      t.integer   :port
      t.string    :path
      t.string    :descr
      t.column    :status, "enum('new', 'active', 'failed', 'deleted')", :default => 'new', null: false, index: true
      
      t.timestamps null: false
    end
    add_index :servers, [:name, :host, :port, :path], unique: true
  end
end
