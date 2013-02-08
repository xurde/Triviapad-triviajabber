require "#{SERVER_PATH}/boot"
require "#{SERVER_PATH}/config/config"
require "#{SERVER_PATH}/lib/triviajabber/triviajabber_base"

server = TriviaServer::Server.instance
#sleep(3)

server.doloop
#server.stop