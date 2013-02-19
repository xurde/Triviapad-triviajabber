SERVER_PATH = "#{File.dirname(__FILE__)}/"

require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: server.rb [options]"
  opts.on("-e","--environment ENVIRONMENT","which environment you want server run") do |environment|
    APP_ENV = options[:environment] = environment
  end

end.parse!

# p options

if !defined? APP_ENV
	puts "Setting App Environment to 'development' by default"
	APP_ENV = 'development'
else
	puts "App Environment is '#{APP_ENV}'."
end