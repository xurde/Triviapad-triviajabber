TRIVIAJABBER_PATH = "#{File.dirname(__FILE__)}/../triviajabber/" 

require "#{TRIVIAJABBER_PATH}/server_base"

SECS_LOOP_STATUS = 30
 
namespace :triviajabber do
  namespace :server do
    desc 'Runs main Jabber Server process from TriviaJabber.'
    task :start => :environment do

      server = TriviaServer::Server.instance
      loop { #main Loop
        server.status
        sleep(SECS_LOOP_STATUS)
      }
    
      server.stop
    end #end task
  end
end