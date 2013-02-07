require './boot'
require './config/config'
require './lib/triviajabber/triviajabber_base'

server = TriviaServer::Server.instance

server.doloop

server.stop