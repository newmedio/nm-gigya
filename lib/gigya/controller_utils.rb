module Gigya
	### Helper/controller mixins
	module ControllerUtils
		GIGYA_SESSION_PARAM = :gigya_token
		GIGYA_QUERY_PARAM = :gigya_token
		GIGYA_COOKIE_PARAM = :gigya_token

		@@gigya_jwt_refresh_time = nil
		def self.gigya_jwt_refresh_time=(val)
			@@gigya_jwt_refresh_time = val
		end

		@@gigya_refresh_time_decay = true
		def self.gigya_jwt_refresh_time
			@@gigya_jwt_refresh_time
		end

		def self.gigya_refresh_time_decay=(val)
			@@gigya_refresh_time_decay = val
		end

		def self.gigya_refresh_time_decay
			@@gigya_refresh_time_decay
		end

		def gigya_user_required
			begin
				render(:json => {:error => "Invalid login"}, :status => 401) if gigya_user_identifier.blank?
			rescue
				render(:json => {:error => "#{$!.message}"}, :status => 401)
			end
		end

		# Obtain the token from the standard places
		def gigya_jwt_token
			@gigya_jwt_token ||= begin
				tmp_token = nil
				token_location = nil

				begin
					authenticate_with_http_token do |token, options|
						tmp_token = token
						token_location = :header
					end
				rescue
					# If this is being called from a helper instead of a controller, then the authenticate_with_http_token is not available.
					# Additionally, we probably can't even use the HTTP Authorization header anyway
				end

				begin
					tmp_token = params[GIGYA_QUERY_PARAM] unless params[GIGYA_QUERY_PARAM].blank?
					token_location = :param
					if tmp_token.blank?
						tmp_token = cookies[GIGYA_COOKIE_PARAM]
						token_location = :cookie
					end
				rescue
					# Some lightweight controllers don't do cookies
				end

				begin
					if tmp_token.blank?
						tmp_token = session[GIGYA_SESSION_PARAM]	
						token_location = :session
					end
				rescue
					# Some lightweight controllers don't do sessions
				end

				token_location = nil if tmp_token.blank?

				@gigya_token_location = token_location

				tmp_token
			end
		end

		def interpret_jwt_token(force = false)
			if @gigya_jwt_info.nil? 
				@gigya_jwt_info = Gigya::Connection.shared_connection.validate_jwt(gigya_jwt_token)

				perform_token_refresh if needs_token_refresh?
			elsif force
				@gigya_jwt_info = Gigya::Connection.shared_connection.validate_jwt(gigya_jwt_token)
			end

			@gigya_jwt_info
		end

		def perform_token_refresh
			gigya_perform_token_refresh
		end

		def gigya_perform_token_refresh
			info = gigya_user_information

			fields = info.keys - ["iss", "apiKey", "iat", "exp", "sub"]
			if @@gigya_refresh_time_decay
				# Refresh only until the original token expires
				# Note that this is slightly leaky
				expiration = (Time.at(info["exp"]) - Time.now).to_i
			else
				# Keep refreshing with the same time period
				expiration = info["exp"] - info["iat"]
			end
			expiration_time = Time.now + expiration
			result = Gigya::Connection.shared_connection.api_get("accounts", "getJWT", {:targetUID => gigya_user_identifier, :fields => fields.join(","), :expiration => expiration})
			token = result["id_token"]

			raise "Unable to refresh token" if token.blank?

			case @gigya_token_location
				when :header
					headers["X-Set-Authorization-Token"] = token
					headers["X-Set-Authorization-Token-Expiration"] = expiration_time.to_i
				when :cookie
					cookies[GIGYA_COOKIE_PARAM] = token
				when :session
					session[GIGYA_SESSION_PARAM] = token
				when :param
					# FIXME - don't know what to do here.
			end
			@gigya_jwt_token = token
			interpret_jwt_token(true) # Force reinterpretation of token
		end

		def gigya_save_jwt(destination = :cookie)
			interpret_jwt_token
			if destination == :cookie
				cookies[GIGYA_COOKIE_PARAM] = gigya_jwt_token
			elsif destination == :session
				cookies[GIGYA_SESSION_PARAM] = gigya_jwt_token
			else
				raise "Invalid Gigya JWT destination"
			end
		end

		def needs_token_refresh?
			needs_token_refresh_for_time?
		end

		def needs_token_refresh_for_time?
			return false if @@gigya_jwt_refresh_time.nil?

			issue_time = Time.at(@gigya_jwt_info["iat"].to_i)

			return issue_time + @@gigya_jwt_refresh_time < Time.now
		end

		def gigya_user_information
			interpret_jwt_token
			@gigya_jwt_info
		end

		def gigya_user_identifier
			@gigya_user_identifier ||= begin
				interpret_jwt_token
				@gigya_jwt_info["sub"]
			end
		end
	end	
end
