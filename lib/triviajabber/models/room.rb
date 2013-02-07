class Room

	include DataMapper::Resource

	property :id,     Serial
	property :name, 	String
	property :slug, 	String
	property :topic, 	String
	property :status, 	String
	property :level, 	String
	property :access, 	String
	property :created_at, 	DateTime
	property :updated_at, 	DateTime
	property :bot, 	String
	property :botpasswd, 	String
	property :games_counter, 	Integer
	property :questions_per_game, 	Integer
	property :seconds_per_question, Integer
	property :signal, 	String

	belongs_to :pool
	has n, :games

end