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

		def interpret_jwt_token
			@gigya_token ||= begin
				tmp_token = nil
				authenticate_with_http_token do |token, options|
					tmp_token = token
				end
				tmp_token = params[GIGYA_QUERY_PARAM] unless params[GIGYA_QUERY_PARAM].blank?
				if tmp_token.blank?
					tmp_token = cookies[GIGYA_COOKIE_PARAM]
				end

				if tmp_token.blank?
					tmp_token = session[GIGYA_SESSION_PARAM]	
				end
				
				tmp_token
			end
			@gigya_jwt_info ||= Gigya::Connection.shared_connection.validate_jwt(@gigya_token)
		end

		def gigya_save_jwt(destination = :cookie)
			interpret_jwt_token
			if destination == :cookie
				cookies[GIGYA_COOKIE_PARAM] = @gigya_token
			elsif destination == :session
				cookies[GIGYA_SESSION_PARAM] = @gigya_token
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
