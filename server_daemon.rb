require './boot'
require './config/config'
require './lib/triviajabber/triviajabber_base'

require 'daemons'

server = TriviaServer::Server.instance

Daemons.run(server.doloop)

#server.stop