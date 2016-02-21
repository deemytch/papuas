class ALogger
  def initialize(fname)
    @log = File.new(fname, 'a')
    at_exit{ @log.close unless @log.closed? }
  end

  def method_missing(name, *args)
    unless %w[debug info warn error crit].include? name
      super
    else
      @log.write "info: " + args.join(' ')
    end
  end
end
