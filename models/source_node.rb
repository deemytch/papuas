require 'net/scp'

class SourceNode < ServerAccount
	has_many :tasks
	has_many :task_reports, :through => :tasks, :dependent => :destroy

=begin
Ищем на host/path все файлы с именем doit-*yml
Грузим во временную папку
Создаём под каждый файл задачу
Если задача создана успешно, то переименовываем на исходном хосте их в taskloaded*
Удаляем временную папку
=end
	def load_tasks!
		Dir.mktmpdir("source-node-#{id}-", $cfg[:global][:tmpdir]) do |tmp|
			$logger.debug "Создал временную папку #{tmp}"
			Net::SFTP.start(host, login, sshparams) do |sftp|
				sftp.dir.foreach(path) do |el|
					# СДЕЛАТЬ: потом тут можно распараллелить, если понадобится
					next unless el.name =~ /^doit-(.+)\.yml$/
					$logger.info "Загружаю файл описания задачи #{path}\t#{el.longname}"
					descr = $1
					tf = sftp.download!("#{path}/#{el.name}")
					task = Task.create taskfile: tf, source_node: self, descr: descr, tmpdir: tmp
					unless task.present?
						$logger.warn "Неправильный файл описания задачи #{login}@#{host}:#{port}/#{path}/#{el.name}"
						next
					end
					dstname = el.name.gsub /^doit-/,"task-#{t.id}-"
					Net::SSH.start(host, login, data) do |ssh|
						ssh.exec! "cd #{path} && mv '#{el.name}' '#{dstname}'"
					end
				end
			end
		end
	rescue Net::SFTP::Error => e
		$logger.warn "Ошибка копирования файлов #{e}"
		failed!
	rescue Net::SSH::ConnectionTimeout => e
		$logger.warn "Ошибка подключения #{e}"
		failed!
	end
end
