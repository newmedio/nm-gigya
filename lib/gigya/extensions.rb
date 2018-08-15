class String
	def to_gigya_user
		Gigya::User.find(self)	
	end
end
