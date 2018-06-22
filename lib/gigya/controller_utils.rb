module Gigya
	### Helper/controller mixins
	module ControllerUtils
		GIGYA_SESSION_PARAM = :gigya_token
		GIGYA_QUERY_PARAM = :gigya_token
		GIGYA_COOKIE_PARAM = :gigya_token

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

				begin
					authenticate_with_http_token do |token, options|
						tmp_token = token
					end
				rescue
					# If this is being called from a helper instead of a controller, then the authenticate_with_http_token is not available.
					# Additionally, we probably can't even use the HTTP Authorization header anyway
				end

				begin
					tmp_token = params[GIGYA_QUERY_PARAM] unless params[GIGYA_QUERY_PARAM].blank?
					if tmp_token.blank?
						tmp_token = cookies[GIGYA_COOKIE_PARAM]
					end
				rescue
					# Some lightweight controllers don't do cookies
				end

				begin
					if tmp_token.blank?
						tmp_token = session[GIGYA_SESSION_PARAM]	
					end
				rescue
					# Some lightweight controllers don't do sessions
				end

				tmp_token
			end
		end

		def interpret_jwt_token
			@gigya_jwt_info ||= Gigya::Connection.shared_connection.validate_jwt(gigya_jwt_token)
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
