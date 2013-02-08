SERVER_PATH = "#{File.dirname(__FILE__)}/"

if !defined? APP_ENV
	puts "Setting default App Environment to 'development'."
	APP_ENV = 'development'
else
	puts "App Environment is '#{APP_ENV}'."
end