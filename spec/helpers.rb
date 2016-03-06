def truncate_tables(dbname = $cfg[:mysql][$database_env][:database])
	table_cmd = `mysql -u root #{dbname} -Nse "show tables"`.
		split(/\s+/).
		collect{|t| "truncate table #{t}" unless t == 'schema_migrations'}.
		compact.join(';')
	system %{ mysql -u root -Nse "SET FOREIGN_KEY_CHECKS = 0; #{ table_cmd }; SET FOREIGN_KEY_CHECKS = 1; " #{dbname} }
end