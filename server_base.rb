TRIVIAJABBER_PATH = "#{File.dirname(__FILE__)}/../triviajabber/" 

#require 'rubygems'

require 'yaml'

require 'xmpp4r'
require 'xmpp4r/muc'
require 'xmpp4r/roster'
require 'xmpp4r/client'
require 'xmpp4r/pubsub'

include Jabber
#Jabber::debug = true

require "#{TRIVIAJABBER_PATH}lib/jabber_extend"
require "#{TRIVIAJABBER_PATH}lib/logger"

require "#{TRIVIAJABBER_PATH}trivia_server/trivia_actors"
require "#{TRIVIAJABBER_PATH}trivia_server/trivia_room"
#require "#{TRIVIAJABBER_PATH}trivia_server/trivia_room_storage"
require "#{TRIVIAJABBER_PATH}trivia_server/trivia_server"


#Load config and make it global constants
begin
  File.open( "#{TRIVIAJABBER_PATH}../../config/triviajabber.yml" ){ |yml| YAML::load( yml ) }.each{|k,v| eval "#{k} = '#{v}'"}
rescue
  puts "HANDLED FATAL ERROR loading triviajabber.yml -> #{$!}"
  exit
end
