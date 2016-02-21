require 'yaml'
class Hash
  def symkeys
    Hash[self.map{|(k,v)| [k.to_sym, v.is_a?(Hash) ? v.symkeys : v]}]
  end
  def with_keys(*ks)
    list = ks
    self.select{|k,v| list.include? k }
  end
end

module Config
  $base ||= File.expand_path(File.dirname(__FILE__))
  $cfg = YAML.load(File.read("#{$base}/config/global.yml")).symkeys
  # rubyver = '2.3.0'
  # ENV['PATH']= "#{$base}/vendor/ruby/2.3.0/bin"
  # ENV['RUBYOPT'] = '-rbundler/setup'
  # ENV['RUBYLIB'] = "#{ENV['HOME']}/.gem/ruby/#{rubyver}/gems/bundler-1.11.2/lib"
  # ENV['GEM_HOME'] = "#{$base}/vendor/ruby/#{rubyver}"
  # ENV['BUNDLE_GEMFILE'] = "#{$base}/Gemfile"
end
