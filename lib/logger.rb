require 'colored'
require 'logger'



class EventLogger
  
  attr_accessor :enabled
  #needs optionaly write to logfile
  
  def initialize(thread_string)
    @thread_string = thread_string.sub(' ', '_').downcase
    @enabled = true
    log_file_path = "#{Rails.root}/log/#{thread_string}.log"
    @logger = Logger.new(log_file_path)
    @logger.progname = thread_string
    #@logger.datetime_format = "%d-%m-%y - %h:%m-%s"
    #@logger.formatter = proc { |severity, datetime, progname, msg| "#{severity} :: #{datetime} :: #{progname} :: #{msg}\n"}
    return @logger
  end
  
  def puts(msg, evnt = :debug, context = nil)
    if @enabled
      text = "[#{@thread_string.upcase}] :: #{evnt.to_s.upcase << ' :: ' if evnt} #{msg}"
      case evnt
      when :fatal
        puts text.black_on_yellow
      when :error
        puts text.on_red
      when :warn
        puts text.cyan
      when :info
        puts text.white
      else #:debug
        puts text.black_on_white
      end
    end
  end
  

  def log(msg, evnt = :debug, context = nil)
    text = "#{evnt.to_s.upcase} :: #{Time.now.strftime("%d-%m-%y %H:%M:%S")} :: [#{context}] -- #{msg}"
    case evnt
    when :fatal
      @logger.fatal(text.yellow_on_red)
    when :error
      @logger.error(text.red)
    when :warn
      @logger.warn(text.yellow)
    when :info
      @logger.info(text.white)
    when :debug
      @logger.debug(text.green)
    else #unknown
      @logger.unknown(context){ text }
    end
  end
  
  
end # class
