module Gigya
	### Helper/controller mixins
	module ControllerUtils
		def gigya_user_required
			begin
				render(:json => {:error => "Invalid login"}, :status => 401) if gigya_user_identifier.blank?
			rescue
				render(:json => {:error => "#{$!.message}"}, :status => 401)
			end
		end

		def interpret_jwt_token
			@token ||= begin
				tmp_token = nil
				authenticate_with_http_token do |token, options|
					tmp_token = token
				end
				tmp_token = params[:token] unless params[:token].blank?
				tmp_token
			end
			@jwt_info ||= Gigya::Connection.shared_connection.validate_jwt(@token)
		end

		def gigya_user_information
			interpret_jwt_token
			@jwt_info
		end

		def gigya_user_identifier
			@gigya_user_identifier ||= begin
				interpret_jwt_token
				@jwt_info["sub"]
			end
		end
	end	
end
