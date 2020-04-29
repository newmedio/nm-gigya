module Gigya
	class User # A model to represent Gigya Account records provided by the API (as JSON hash)
		attr_accessor :gigya_details
		attr_accessor :gigya_connection

		@@extra_profile_fields = ["locale", "phones"]
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
			conn = my_gigya_connection
			set_attributes(conn.api_get("accounts", "getAccountInfo", {UID: uid, include:"profile,data,subscriptions,userInfo,preferences", extraProfileFields:@@extra_profile_fields.join(",")}))
		end

		def save
			info = {UID: uid}
			info["profile"] = gigya_details["profile"].to_json if gigya_details["profile"].present?
			info["data"] = gigya_details["data"].to_json if gigya_details["data"].present?
			# What about isActive, isVerified?, password/newPassword, preferences, add/removeLoginEmails, subscriptions, lang, rba

			conn = my_gigya_connection
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
			resp = conn.api_get("accounts", "search", {:query => "SELECT UID FROM accounts WHERE profile.email = \"#{email}\""})
			uid = resp["results"][0]["UID"] rescue nil
			return nil if uid.blank?
			return self.find(uid, opts)
		end

		def self.find(uid, opts = {}) # Find a Gigya account record by its UID attribute
			opts = {} if opts.nil?
			opts[:cache] = true if opts[:cache].nil?

			cache_info = load_from_cache(uid)
			if cache_info.present? && opts[:cache]
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
			profile = gigya_details["profile"] rescue nil
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


		# Intended way of calling this:
		# Gigya::User.create_gigya_user_through_notify_login("abc@example.com", :password => "Abc123!!", :account => { "preferences" => {"foo" => "bar" } }, :verified => true)
		#
		# Options:
		#   :password => Set a password,
		#   :source => the registration source
		#   :account => hash of any account defaults you want to set.  Profile defaults should be under the "profile" key.
		#   :send_verification => Will send verification email
		#   :verified => Will auto-set "verified"
		#   :force => Will do things that Gigya doesn't naturally want to do (often used in combination with :verified)
		#   :debug => will print out call information	

		# Creates a gigya user through the `notify_login` pathway
		def self.create_gigya_user_through_notify_login(email, opts = {})
			conn = opts[:gigya_connection] || Gigya::Connection.shared_connection

			# Create UUID
			new_uid = opts[:UID] || "#{SecureRandom.uuid.gsub("-", "")}#{SecureRandom.uuid.gsub("-", "")}"

			# Is the address available?
			email_is_available = conn.api_get("accounts", "isAvailableLoginID", { "loginID" => email }, :debug_connection => opts[:debug])["isAvailable"] rescue false
			raise "Username is unavailable" unless email_is_available

			# Register UUID
			response = conn.api_get("accounts", "notifyLogin", {"siteUID" => new_uid}, :debug_connection => opts[:debug])
			raise "Could not register UID" unless response["errorCode"] == 0 || response["errorCode"] == 206001

			# Start the registration process
			regtoken = conn.api_get("accounts", "initRegistration", {}, :debug_connection => opts[:debug])["regToken"] rescue nil
			raise "Could not initiate registration" if regtoken.blank?

			# Create the data record
			account_info = opts[:account] || {}        # This allows the caller to send us defaults
			account_info["UID"] = new_uid              # Primary key
			account_info["regToken"] = regtoken        # Ties it to the initial registration
			account_info["securityOverride"] = true    # Allows us to set passwords if we want
			account_info["profile"] ||= {}
			account_info["profile"]["email"] = email   # Actual login username
			account_info["profile"] = account_info["profile"].to_json
			account_info["preferences"] = account_info["preferences"].to_json
			account_info["regSource"] = opts[:source] || "nm-gigya"

			# Optional data record pieces
			account_info["isVerified"] = true if opts[:verified]
			account_info["newPassword"] = opts[:password] unless opts[:password].blank?

			# Create the registration with the data record
			results = conn.api_post("accounts", "setAccountInfo", account_info, :debug_connection => opts[:debug])

			# If not everything got set correctly (NOTE - doesn't work if :password is not also sent)
			if opts[:force]
				response = conn.api_get("accounts", "login", {"loginID" => email, "password" => opts[:password]}, :debug_connection => opts[:debug])
				if response["errorCode"] != 0
					verify_reg_token = response["regToken"]
					response = conn.api_get("accounts", "finalizeRegistration", {"regToken" => verify_reg_token, "include" => "emails, profile"}, :debug_connection => opts[:debug])
					unless response["errorCode"] == 0 || response["errorCode"] == 206002 || response["errorCode"] == 206001
						raise "Unable to finalize registration" 
					end
				end
			end

			if opts[:send_verification]
				conn.api_get("accounts", "resendVerificationCode", {"UID" => new_uid, "email" => email})
			end

			if opts[:send_password_change]
				conn.api_get("accounts", "resetPassword", {"UID" => new_uid, "loginID" => email, "email" => email})
			end

			return new_uid
		end

		# Creates a gigya user through the `register` pathway

		# Options:
		#   :password => Set a password,
		#   :source => the registration source
		#   :account => hash of any account defaults you want to set.  Profile defaults should be under the "profile" key.
		#   :debug => will print out call information

		def self.create_gigya_user_through_register(email, opts = {})
			conn = opts[:gigya_connection] || Gigya::Connection.shared_connection

			new_password = opts[:password] || SecureRandom.urlsafe_base64(8)

			# Create UUID
			new_uid = opts[:UID] || "#{SecureRandom.uuid.gsub("-", "")}#{SecureRandom.uuid.gsub("-", "")}"

			# Is the address available?
			email_is_available = conn.api_get("accounts", "isAvailableLoginID", { "loginID" => email }, :debug_connection => opts[:debug])["isAvailable"] rescue false
			raise "Username is unavailable" unless email_is_available

			# Start the registration process
			regtoken = conn.api_get("accounts", "initRegistration", {}, :debug_connection => opts[:debug])["regToken"] rescue nil
			raise "Could not initiate registration" if regtoken.blank?

			# Create the data record
			account_info = opts[:account] || {}        # This allows the caller to send us defaults
			account_info["siteUID"] = new_uid              # Primary key
			account_info["regToken"] = regtoken        # Ties it to the initial registration
			account_info["profile"] ||= {}
			account_info["email"] = email
			account_info["profile"]["email"] = email   # Actual login username
			account_info["profile"] = account_info["profile"].to_json
			account_info["preferences"] = account_info["preferences"].to_json unless account_info["preferences"].nil?
			account_info["regSource"] = opts[:source] unless opts[:source].blank?
			account_info["password"] = new_password
			account_info["data"] = account_info["data"].to_json unless account_info["data"].nil?

			# Complete the registration process
			conn.api_post("accounts", "register", account_info, :debug_connection => opts[:debug])

			if opts[:send_verification]
				conn.api_get("accounts", "resendVerificationCode", {"UID" => new_uid, "email" => email})
			end

			if opts[:send_password_change]
				conn.api_get("accounts", "resetPassword", {"UID" => new_uid, "loginID" => email, "email" => email})
			end

			return new_uid
		end

		private

		def my_gigya_connection
			gigya_connection || Gigya::Connection.shared_connection
		end
	end
end
