%w[errors task_report task server_account source_node task_node].each do |src|
  require_relative "#{$base}/models/#{src}.rb"
end

module Listing
	def self.list_servers(kind = nil, name = nil)
		nodes = ServerAccount.all
		if ! name.nil? && ! name.empty?
			nodes = ServerAccount.id_name_uri(name)
		end
		if ! kind.nil?
			nodes = nodes.where(kindof: kind)
		end
		nodes = nodes.order(:host, :port, :name, :status, :created_at).collect do |node|
			[	server_type_letter(node.kindof), node.id, node.status,
				node.name, node.uri, 
				node.created_at.strftime("%d/%m/%Y %H:%M"),
				node.descr ]
		end
		$logger.debug "servers #{nodes.to_a.count}"
		return TTY::Table.new(
			header: %w[* # состояние имя uri добавлен описание],
			rows: nodes).render(:unicode)
	end

	def self.list_nodes(name=nil)
		list_servers('TaskNode', name)
	end

	def self.list_sources(name=nil)
		list_servers('SourceNode', name)
	end

	def self.list_tasks(searchs = nil)	
		if searchs
			if searchs =~ /^\d+$/ && t = Task.find_by(id: searchs)
				tasks = [t]
			elsif (accounts = ServerAccount.host_or_uri(searchs)).any?
				tasks = Task.where(source_node_id: accounts.ids).joins(:source_node).
					order(:status, :created_at, 'server_accounts.host', 'server_accounts.port')
			end
		else
			tasks = Task.all
		end
		return 'Ничего не найдено' if tasks.nil? || tasks.empty?
		taskrep = tasks.collect do |task|
			[  task.id, task.status, task.source_node.uri,
				task.task_nodes.collect{|n| n.uri}.join("\n"),
				task.script, task.settings[:files].count,
				task.created_at, task.descr
			]
		end
		return TTY::Table.new(
			header: %w[# состояние исходный назначение имя-скрипта доп.файлы добавлен описание],
			rows: taskrep).render(:unicode)
	end

	def self.server_type_letter(t)
		t.to_s[0]
	end
end
