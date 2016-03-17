class String
	def to_ssh_uri
		u = URI( self =~ /^ssh:/ ? self : 'ssh://' + self)
		Hash[u.instance_variables.map{|k| [k[1..-1], u.instance_variable_get(k)] }].
			select{|k,v| v && %w[user host port path password].include?(k) && ! v.empty? }
	end
	def is_ssh_uri?
		self =~ /^(\w@)?.+:(\d+)?|\w@\w/
	end
end