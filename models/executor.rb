=begin
  Занести все изменения в базу, с пометкой "не сейчас"
  если не выполняется никаких задач - записать всё
=end
module Executor
	def self.add_changes!(o)
		$logger.debug "Выполняю: "
		o.each do |cmd|
			$logger.debug "#{cmd[:action]}"
			case cmd[:action]
			when :off # name:[id,uri,name]
				x = cmd[:t].id_name_uri(cmd[:name]).first
				if x.present?
					x.power_off!
					$logger.info "Выключен объект #{x.class}: #{x.inspect};"
				else
					$logger.error "Не удалось найти объект #{cmd[:name]}\n\t#{e}"
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
						$exitcode += 1
					end
				end
			when :del
				x = cmd[:t].id_name(cmd[:name]).first
				if x.present?
					x.destroy
					$logger.info "Удалён объект #{cmd[:params]}"
				else
					$logger.error "Не удалось удалить объект #{cmd[:name]}\n\t#{x.errors.inspect}"
				end
			when :check
				@srv = cmd[:name] ? ServerAccount.id_name_uri(cmd[:name]) : ServerAccount.where("status != 'deleted'")
				@srv.each{|node| node.check! }
			when :logrotate
				zap!
			when :publish
				repfn = "#{$cfg[:global][:tmpdir]}/#{$cfg[:appsetup][:publish]}"
				$logger.debug "Записываю отчёт в #{repfn}"
				File.open(repfn, 'w'){|f| f.write Listing.list_users	}
				chan = []
				$logger.debug "Начинаю копировать на источники"
				SourceNode.with_active_state.each do |node|
					$logger.debug "узел #{node.name}"
					node.login do |ssh|
						$logger.debug "Копирую файл справочника на #{node.name}"
						out = ssh.scp.upload!(repfn, node.uri)
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
