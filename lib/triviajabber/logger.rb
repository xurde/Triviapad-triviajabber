require 'colored'
require 'logger'



class EventLogger
  
  attr_accessor :enabled
  #needs optionaly write to logfile
  
  def initialize(thread_string)
    @thread_string = thread_string.sub(' ', '_').downcase
    @enabled = true
    log_file_path = "./log/#{thread_string}.log"
    @logger = Logger.new(log_file_path)
    @logger.progname = thread_string
    @logger.formatter = proc { |severity, datetime, progname, msg| "#{severity} :: #{datetime.strftime('%d-%m-%y %H:%M:%S')} :: #{progname} :: #{msg}\n"}
    return @logger
  rescue
    puts "FATAL ERROR! Can't create logfile for '#{log_file_path}'"
  end
  
  def puts(msg, evnt = :debug, context = nil)
    if @enabled
      text = "[#{@thread_string.upcase}] :: #{evnt.to_s.upcase << ' :: ' if evnt} #{msg}"
      case evnt
      when :fatal
        puts text.yellow_on_red
      when :error
        puts text.red
      when :warn
        puts text.yellow
      when :info
        puts text.white
      when :debug
        puts text.black_on_white
      else
        puts text.black_on_white
      end
    end
  end
  

  def log(msg, evnt = :debug, context = nil)
    # text = "#{evnt.to_s.upcase} :: #{Time.now.strftime("%d-%m-%y %H:%M:%S")} :: [#{context}] -- #{msg}"
    case evnt
    when :fatal
      @logger.fatal(msg.yellow_on_red)
    when :error
      @logger.error(msg.red)
    when :warn
      @logger.warn(msg.yellow)
    when :info
      @logger.info(msg.white)
    when :debug
      @logger.debug(msg.black_on_white)
    else #unknown
      @logger.unknown(context){ msg }
    end
  end
  
  
end # class
