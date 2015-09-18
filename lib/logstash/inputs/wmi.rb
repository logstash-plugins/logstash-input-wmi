# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "socket"
require "stud/interval"

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
    @wmi = WIN32OLE.connect("winmgmts://")
    
    begin
      while !stop?
        @logger.debug("Executing WMI query '#{@query}'")
        @wmi.ExecQuery(@query).each do |wmiobj|
          # create a single event for all properties in the collection
          event = LogStash::Event.new
          event["host"] = @host
          decorate(event)
          wmiobj.Properties_.each do |prop|
            if prop.value.is_a?(String)
              event[prop.name] = prop.value.force_encoding(Encoding::UTF_8)
            else
              event[prop.name] = prop.value
	    end
          end
          queue << event
	  break if stop?
        end
        Stud.stoppable_sleep(@interval) { stop? }
      end # loop
    rescue Exception => ex
      @logger.error("WMI query error: #{ex}\n#{ex.backtrace}")
      Stud.stoppable_sleep(@interval) { stop? }
      retry
    end # begin/rescue
  end # def run
end # class LogStash::Inputs::WMI
