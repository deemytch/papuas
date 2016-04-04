%w[errors task_report task server_account source_node task_node].each do |src|
  require_relative "#{$base}/models/#{src}.rb"
end

module Listing
	def self.list_servers(kind = nil, name = nil, renderer = :unicode)
		nodes = ServerAccount.all
		if ! name.nil? && ! name.empty?
			nodes = ServerAccount.id_name_uri(name)
		end
		if ! kind.nil?
			nodes = nodes.where(kindof: kind.to_s)
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
			rows: nodes).render(renderer, multiline: true)
	end

	def self.list_nodes(name=nil)
		list_servers('TaskNode', name)
	end

	def self.list_sources(name=nil)
		list_servers('SourceNode', name)
	end

	def self.list_tasks(searchs = nil, renderer = :unicode)
		if searchs # подробный состояние задачи
			if searchs =~ /^\d+$/ && t = Task.find_by(id: searchs)
				tasks = [t]
			elsif (accounts = ServerAccount.host_or_uri(searchs)).any?
				tasks = Task.where(source_node_id: accounts.ids).joins(:source_node).
					order(:status, :created_at, 'server_accounts.host', 'server_accounts.port')
			end
			return 'Ничего не найдено' if tasks.nil? || tasks.empty?
			ou = ''
			tasks.each do |t|
				rows =
					[["#{t.descr}"],
					["задача id: #{t.id}; source: #{t.source_node.id}, #{t.source_node.name}, #{t.source_node.uri}"],
					["назначение: #{t.task_nodes.pluck(:name).join(', ')};"],
					["скрипт: #{t.settings['script']}, доп. файлы: #{t.settings['filelist'].join(', ')};"]]
				ou += TTY::Table.new(rows).render(renderer, multiline: true) + "\n" +
				t.task_reports.collect do |trep|
					"узел: ##{trep.task_node.id}, #{trep.task_node.name}, #{trep.task_node.uri}\n" +
					"STDOUT:\n#{trep.stdout_log}\n" +
					"STDERR:\n#{trep.stderr_log}\n"
				end.join("───────────────────────────────\n") + "\n"
			end
			return ou
		else # краткий список задач
			tasks = Task.all.order(:status)
			return 'Ничего не найдено' if tasks.nil? || tasks.empty?
			taskrep = tasks.collect do |task|
			[  task.status[0].upcase, task.id, task.source_node.name,
				task.task_nodes.collect{|n| n.name}.join("\n"),
				task.script, task.settings['filelist'].count,
				task.created_at.strftime("%d/%m %H:%M"), task.descr
			]
			end
			return TTY::Table.new(
				header: %w[* # исходный назначение имя-скрипта доп.файлы добавлен описание],
				rows: taskrep).render(renderer, multiline: true) +
				"\nвсего #{tasks.count}"
		end
	end

	def self.server_type_letter(t)
		t.to_s[0]
	end
end
