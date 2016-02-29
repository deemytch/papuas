class CreateUsersServers < ActiveRecord::Migration
	def change
		create_table :users_servers do |t|
	    	t.references :server, null: false, foreign_key: true, index: true
			t.references :user, null: false, index: true, foreign_key: true
	      t.timestamps null: false
		end
		add_index :users_servers, [:server_id, :user_id], unique: true
	end
end
