class String
	def to_gigya_user
		Gigya::User.from_string(self)	
	end
end
