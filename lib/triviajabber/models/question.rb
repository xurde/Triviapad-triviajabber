class Question

	include DataMapper::Resource

	property :id,     	Serial
	property :created_at, 	DateTime
	property :updated_at, 	DateTime
	#property :pool_id, 	Integer
	property :question, String
	property :answer, 	String
	property :option1, 	String
	property :option2, 	String
	property :option3, 	String

	belongs_to :pool
    
end