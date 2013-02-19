TRIVIAJABBER_PATH = "#{File.dirname(__FILE__)}/" 

require 'rubygems'

require 'yaml'

require 'xmpp4r'
require 'xmpp4r/muc'
require 'xmpp4r/roster'
require 'xmpp4r/client'
require 'xmpp4r/pubsub'

include Jabber
#Jabber::debug = true

require "#{TRIVIAJABBER_PATH}/jabber_extend"
require "#{TRIVIAJABBER_PATH}/logger"

require "#{TRIVIAJABBER_PATH}triviaserver/trivia_actors"
require "#{TRIVIAJABBER_PATH}triviaserver/trivia_room"
#require "#{TRIVIAJABBER_PATH}trivia_server/trivia_room_storage"
require "#{TRIVIAJABBER_PATH}triviaserver/trivia_server"


#Load config and make it global constants
begin
  File.open( "#{TRIVIAJABBER_PATH}../../config/triviajabber.yml" ){ |yml| YAML::load( yml ) }.each{|k,v| eval "#{k} = '#{v}'"}
rescue
  puts "FATAL ERROR when loading triviajabber.yml -> #{$!}"
  exit
end
