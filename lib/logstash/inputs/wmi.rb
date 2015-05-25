# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "socket"


# Collect data from WMI query
#
# This is useful for collecting performance metrics and other data
# which is accessible via WMI on a Windows host
#
# Example:
# [source,ruby]
#     input {
#       wmi {
#         query => "select * from Win32_Process"
#         interval => 10
#       }
#       wmi {
#         query => "select PercentProcessorTime from Win32_PerfFormattedData_PerfOS_Processor where name = '_Total'"
#       }
#     }
class LogStash::Inputs::WMI < LogStash::Inputs::Base

  config_name "wmi"

  # WMI query
  config :query, :validate => :string, :required => true
  # Polling interval
  config :interval, :validate => :number, :default => 10
  # Remote parameters (defaults to localhost without auth)
  config :host, :validate => :string, :default => 'localhost'
  config :user, :validate => :string
  config :password, :validate => :string
  config :namespace, :validate => :string, :default => 'root\cimv2'
  
  public
  def register

    @host = Socket.gethostname
    @logger.info("Registering wmi input", :query => @query)

    if RUBY_PLATFORM == "java"
      require "jruby-win32ole"
    else
      require "win32ole"
    end
  end # def register

  public
  def run(queue)
    if (@host == "127.0.0.1" || @host == "localhost")
      @wmi = WIN32OLE.connect('winmgmts:')
      @host = Socket.gethostname
    else
      locator = WIN32OLE.new("WbemScripting.SWbemLocator")
      @host = Socket.gethostbyname(@host)[0]
      @wmi = locator.ConnectServer(@host, @namespace, @user, @password)
    end
    
    begin
      @logger.debug("Executing WMI query '#{@query}'")
      loop do
        @wmi.ExecQuery(@query).each do |wmiobj|
          # create a single event for all properties in the collection
          event = LogStash::Event.new
          event["host"] = @host
          decorate(event)
          wmiobj.Properties_.each do |prop|
            event[prop.name] = prop.value
          end
          queue << event
        end
        sleep @interval
      end # loop
    rescue Exception => ex
      @logger.error("WMI query error: #{ex}\n#{ex.backtrace}")
      sleep @interval
      retry
    end # begin/rescue
  end # def run
end # class LogStash::Inputs::WMI
