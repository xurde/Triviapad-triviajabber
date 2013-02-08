#requires for Datamapper
require 'dm-core'
require 'dm-validations'
#require 'dm-mysql-adapter'

DataMapper.setup :default, YAML::load(File.open("#{SERVER_PATH}/config/database.yml"))[APP_ENV]

#Load models at ./models/*
require TRIVIAJABBER_PATH + 'models/question'
require TRIVIAJABBER_PATH + 'models/pool'
require TRIVIAJABBER_PATH + 'models/room'
require TRIVIAJABBER_PATH + 'models/game'
require TRIVIAJABBER_PATH + 'models/player'

DataMapper.finalize