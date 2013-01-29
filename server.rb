#require 'boot'
require 'lib/triviajabber/server_base'

server = TriviaServer::Server.instance

server.doloop

server.stop