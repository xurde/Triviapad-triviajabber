class Game

	include DataMapper::Resource

	property :id,     	Serial
	property :room_id, 	Integer
	property :created_at, 	DateTime
	property :updated_at, 	DateTime
	property :counter, 	Integer
	property :time_start, 	DateTime
	property :time_end, 	DateTime
	property :players_max, 	Integer
	property :winner_score, Integer
	property :total_score, 	Integer


	belongs_to :room

	validates_presence_of :counter, :time_start
    
end