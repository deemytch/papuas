class CreateTask < ActiveRecord::Migration
  def change
    create_table :tasks do |t|
    	t.references :source_node, null: false, index: true
		t.string   :settings,       null: false
		t.string   :script,         null: false
		t.string   :data
		t.string   :descr
		t.datetime :started_at
		t.datetime :stopped_at
		t.column   :status, "enum('new', 'active', 'done', 'failed')", :default => 'new', null: false, index: true
		
      t.timestamps null: false
    end
    add_foreign_key :tasks, :servers, :column => :source_node_id
  end
end