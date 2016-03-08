class CreateUserAccounts < ActiveRecord::Migration
	def change
		create_table :user_accounts do |t|
	    	t.references :server, null: false, foreign_key: true, index: true
			t.references :user, null: false, index: true, foreign_key: true
			t.string :path
	      t.timestamps null: false
		end
		add_index :user_accounts, [:server_id, :user_id, :path], unique: true
	end
end
