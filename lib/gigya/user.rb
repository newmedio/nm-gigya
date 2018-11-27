module Gigya
	class User # A model to represent Gigya Account records provided by the API (as JSON hash)
		attr_accessor :gigya_details
		attr_accessor :gigya_connection

		@@extra_profile_fields = ["locale"]
		def self.extra_profile_fields=(val)
			@@extra_profile_fields = val
		end
	
		def self.extra_profile_fields
			@@extra_profile_fields
		end

		@@default_gigya_user_class = nil
		def self.default_gigya_user_class
			@@default_gigya_user_class
		end

		def self.default_gigya_user_class=(val)
			@@default_gigya_user_class = val
		end

		def self.from_string(str)
			uc = @@default_gigya_user_class || Gigya::User
			uc = Kernel.const_get(uc) if String === uc
			uc.find(str)
		end

		@@cache_options = {}
		def self.cache_options
			@@cache_options 
		end

		def self.cache_options=(val)
			@@cache_options = val
		end

		# A user can be initialized with a JSON hash of a Gigya account record
		def initialize(json = {}, needs_caching = true) 
			# needs_caching is used for internal methods which load the record from cache and therefore don't need to save to cache
			set_attributes(json)
			save_to_cache if needs_caching

			return nil
		end

		def set_attributes(json = {})
			self.gigya_details = json
		end

		def reload
			conn = gigya_connection || Gigya::Connection.shared_connection
			set_attributes(conn.api_get("accounts", "getAccountInfo", {UID: uid, include:"profile,data,subscriptions,userInfo,preferences", extraProfileFields:@@extra_profile_fields.join(",")}))
		end

		def save
			info = {UID: uid}
			info["profile"] = gigya_details["profile"].to_json if gigya_details["profile"].present?
			info["data"] = gigya_details["data"].to_json if gigya_details["data"].present?
			# What about isActive, isVerified?, password/newPassword, preferences, add/removeLoginEmails, subscriptions, lang, rba

			conn = gigya_connection || Gigya::Connection.shared_connection	
			conn.api_post("accounts", "setAccountInfo", info)
			save_to_cache

			return true
		end

		def save_to_cache
			if defined?(Rails)
				u = uid
				return if u.blank? # Don't save a blank object
				Rails.cache.write("gigya-user-#{u}", gigya_details)
			else
				# Nothing to do
			end
		end
	
		def self.load_from_cache(uid)
			if defined?(Rails)
				return Rails.cache.read("gigya-user-#{uid}")
			else
				return nil
			end
		end

		def self.find_by_email(email, opts = {})
			email = email.gsub('"', '') # get rid of quotes
			opts = {} if opts.nil?
			conn = opts[:connection] || Gigya::Connection.shared_connection
			resp = conn.api_get("accounts", "search", {:query => "SELECT uid FROM accounts WHERE profile.email = \"#{email}\""})
			uid = resp["results"][0]["UID"] rescue nil
			return nil if uid.blank?
			return self.find(uid, opts)
		end

		def self.find(uid, opts = {}) # Find a Gigya account record by its UID attribute
			opts = {} if opts.nil?

			cache_info = load_from_cache(uid)
			if cache_info.present?
				return self.new(cache_info, false)
			else
				connection = opts[:connection] || Gigya::Connection.shared_connection
				response = connection.api_get("accounts", "getAccountInfo", {UID: uid, include:"profile,data,subscriptions,userInfo,preferences", extraProfileFields:@@extra_profile_fields.join(",")})
				obj = self.new(response)
				obj.gigya_connection = connection
				return obj
			end
		end

		### Gigya accessors
		def uid
			gigya_details["UID"] rescue nil
		end

		def created_at
			DateTime.strptime(gigya_details["createdTimestamp"].to_s, "%Q") rescue nil
		end

		def full_name
			[first_name, last_name].join(" ")
		end

		def first_name
			gigya_details["profile"]["firstName"].to_s.capitalize rescue nil
		end

		def last_name
			gigya_details["profile"]["lastName"].to_s.capitalize rescue nil
		end

		def email
			gigya_details["profile"]["email"].to_s.downcase rescue nil
		end

		def birthday
			profile = gigya_details["profile"]
			Date.new(profile["birthYear"], profile["birthMonth"], profile["birthDay"]) rescue nil
		end

		def gender
			gigya_details["profile"]["gender"] rescue nil
		end

		def locale
			gigya_details["profile"]["locale"] rescue nil
		end

		def gender_string
			begin
				case gigya_details["profile"]["gender"]
					when "f"
						"Female"
					when "m"
						"Male"
					else
						nil
				end
			rescue
				nil
			end
		end
	end
end
