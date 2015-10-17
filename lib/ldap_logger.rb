require 'rubygems'
require 'log4r'

# Wraps our log4r config in a class
# We send all methods to the @log instance variable

class LdapLogger
  include Log4r
  def initialize
    @current_time = Time.new
    @log = Logger.new 'log'
    @log_file = FileOutputter.new(
      'log_file',
      :trunc => false,
      :filename => "#{GLOBAL_LDAP_ROOT}/logs/#{@current_time.strftime( '%Y-%m-%d' )}.log"
    )
    @log_file.formatter = PatternFormatter.new( :pattern => '[%l] %d :: %m' )
    @log.outputters = @log_file
  end
  def method_missing( method, *args, &block )
    @log.send( method.to_sym, args )
  end
end
