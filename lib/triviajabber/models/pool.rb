class Pool

	include DataMapper::Resource

	property :id,     	Serial
	property :created_at, 	DateTime
	property :updated_at, 	DateTime
	property :name, 	String
  property :desc, 	String
  property :lang, 	String
  property :country, 	String

  has n, :questions
	has n, :rooms


	def get_random_question
		total = self.questions.size
		rndm = rand(total)
		# SELECT * FROM questions ORDER BY id LIMIT 1 OFFSET 1
		return self.questions.first(:order => [ :id.asc ], :offset => rndm)
  end
    
end