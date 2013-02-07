class Player

	include DataMapper::Resource
	

	property :id,   Serial
	property :jid, 	String
	property :nickname, String
	property :domain, 	String
	property :last_join, DateTime
	property :times_joined, Integer


	def joined!
		self.last_join = Time.now
		self.times_joined += 1
		self.save
	end

end