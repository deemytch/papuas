=begin
  Занести все изменения в базу, с пометкой "не сейчас"
  если не выполняется никаких задач - записать всё
=end
module Executor
	def self.add_changes!(o)
		$logger.debug "Выполняю: "
		o[:commands].each do |cmd|
			$logger.debug "#{cmd[:action]}"
			case cmd[:action]
			when :list
				puts Listing.list_servers(cmd[:t], cmd[:name], o[:flags][:render])
			when :off # name:[id,uri,name]
				x = cmd[:t].id_name_uri(cmd[:name]).first
				if x.present?
					x.power_off!
					$logger.info "Выключен объект #{x.class}: #{x.inspect};"
				else
					$logger.error "Не удалось найти объект #{cmd[:name]}"
				end
			when :on # name:[id,uri,name]
				x = cmd[:t].id_name_uri(cmd[:name]).first
				if x.present?
					x.check!
					$logger.info "Включён объект #{x.class}: #{x.inspect};"
				else
					$logger.error "Не удалось найти объект #{cmd[:name]}"
				end
			when :add # и :mod
				x = cmd[:t].id_name(cmd[:name]).first
				if x.present?
					p = { name: cmd[:name] }.merge(cmd[:params] || {})
					$logger.debug ":mod #{cmd[:name]} <- #{p}"
					if x.update(p)
						$logger.info "Изменён объект #{x.class}: #{x.inspect};"
					else
						$logger.error "Ошибка обновления: #{x.errors.inspect};"
					end
				else
					$logger.debug "добавляю новую запись"
					data = cmd[:params] || {}
					if cmd[:name].is_ssh_uri?
						data.merge! uri: cmd[:name]
					else
						data.merge! name: cmd[:name]
					end
					x = cmd[:t].new data
					if x.save
						$logger.info "Создан объект #{x.class}: #{x.inspect};"
					else
						$logger.error "Не удалось создать объект #{x}\n\t#{x.errors.inspect}"
					end
				end
			when :del
				cmd[:t] == ServerAccount ? 
					x = cmd[:t].id_name(cmd[:name]).first :
					x = cmd[:t].find(cmd[:name][1..-1])
				if x.present?
					x.destroy
					$logger.info "Удалён объект #{cmd[:params]}"
				else
					$logger.error "Не удалось удалить объект #{cmd[:name]}\n\t#{x.errors.inspect}"
				end
			when :check
				@srv = cmd[:name] ? ServerAccount.id_name_uri(cmd[:name]) : ServerAccount.where(status: %w[new processing fail])
				@srv.each{|node| node.check! }
			when :logrotate
				zap!
			when :tasklist
				if cmd.key?(:remote)
					tasks = cmd[:remote].nil? ? Task.all : Task.id_name_uri(cmd[:remote])
					$logger.debug "найдено задач #{tasks.count}; завершённых #{tasks.with_done_state.count};"
					tasks.with_done_state.each{|t| t.publish_reports }
				else
					puts Listing.list_tasks(cmd[:name])
					exit
				end
			when :publish
				repfn = "#{$cfg[:global][:cachedir]}/#{$cfg[:appsetup][:publish]}"
				$logger.debug "Записываю отчёт в #{repfn}"
				File.open(repfn, 'w'){|f| f.write Listing.list_nodes	}
				nodes = SourceNode.where(status: [:active, :dirty])
				$logger.debug "Начинаю копировать на источники: [#{nodes.pluck(:name).join(', ')}]"
				nodes.each do |node|
					$logger.debug "узел #{node.name}"
					node.login do |ssh|
						$logger.debug "Копирую файл справочника на #{node.name}/#{node.path}"
						out = ssh.scp.upload!(repfn, node.path)
						$logger.debug out
					end
				end
			when :zap
				zap!
			end
		end
	end
	def self.zap!
		ServerAccount.with_deleted_state.each{|n| n.destroy }
		Task.with_deleted_state.each{|n| n.destroy }
	end
end
