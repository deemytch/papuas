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
  basedir ||= File.expand_path(File.dirname(__FILE__))
  $cfg = YAML.load(File.read("#{basedir}/config/global.yml")).symkeys
end
