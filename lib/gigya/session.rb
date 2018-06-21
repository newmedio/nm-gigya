# This module is a mix-in that makes for much easier Gigya UI integration in Gigya apps.
# Essentially if you include this, it is very straightforward to do a Gigya login mechanism.
module Gigya::Session
	def self.included(base)
		base.include Gigya::ControllerUtils
		base.extend ClassMethods
	end

	def destroy
		cookies.delete Gigya::ControllerUtils::GIGYA_COOKIE_PARAM
	end

	def create
		gigya_save_jwt(self.class.gigya_token_storage || :cookie)

		if params[:redirect].blank?
			redir = self.class.gigya_after_login_redirect
			case redir
				when String
					redirect_to redir
				when Symbol
					redirect_to self.send(redir)
				else
					redirect_to redir.call
			end
		else
			redirect_to params[:redirect]
		end
	end

	def new
		head_code = <<EOF
<script type='text/javascript' src='https://cdns.gigya.com/js/gigya.js?apikey=#{self.class.gigya_api_key}'></script>
<script type="text/javascript">
	function did_login(evt, resp) {
		form = document.getElementById("hidden-login-form");
		gtok = document.getElementById("gigya-token");

		gtok.value = resp.id_token;
		form.submit();
	}

	var expire_time = #{self.class.gigya_token_expire_time};
	gigya.accounts.showScreenSet({
		screenSet: '#{self.class.gigya_screen_set}',
		startScreen: '#{self.class.gigya_start_screen}',
		containerID: 'gigya-screenset-container',
		deviceType: 'mobile',
		sessionExpiration: expire_time,
		onAfterSubmit: function(evt) {
			if(evt.form == 'gigya-login-form' && evt.response.errorCode == 0) {
				gigya.accounts.getJWT({
					fields: "#{self.class.gigya_jwt_fields}",
					expiration: expire_time,
					callback: function(resp) {
						did_login(evt, resp);
					}
				});
			}
		}
	});
</script>
EOF
		body_code = <<EOF
<%= form_tag request.path.gsub('/new', ''), :id => "hidden-login-form" do %>
	<%= hidden_field_tag :redirect, params[:redirect] %>
	<%= hidden_field_tag :gigya_token, "", :id => "gigya-token" %>
<% end %>
<div class="gigya-screenset-class" id="gigya-screenset-container"></div>
EOF

		if self.class.gigya_script_content_for.present?
			head_code = "<% content_for :#{gigya_script_content_for} do %>#{head_code}<% end %>"
		end

		full_erb = head_code + body_code
		render :inline => full_erb
	end

	module ClassMethods
		def gigya_screen_set(val = nil)
			return (@gigya_screen_set || "Default-RegistrationLogin") if val.nil?
			@gigya_screen_set = val
		end

		def gigya_start_screen(val = nil)
			return (@gigya_start_screen || "gigya-login-screen") if val.nil?
			@gigya_start_screen = val
		end

		def gigya_token_storage(val = nil)
			return (@gigya_token_storage || :cookie) if val.nil?
			@gigya_token_storage = val
		end

		def gigya_after_login_redirect(val = nil)
			return (@gigya_after_login_redirect || :root_path) if val.nil?
			@gigya_after_login_redirect = val
		end

		def gigya_script_content_for(val = nil)
			return @gigya_script_content_for if val.nil?
			@gigya_script_content_for = val
		end

		def gigya_token_expire_time(val = nil)
			return (@gigya_token_expire_time || (60 * 60 * 24)) if val.nil?
		end

		def gigya_jwt_fields(val = nil)
			return (@gigya_jwt_fields || "firstName,lastName,email") if val.nil?
			@gigya_jwt_fields = val
		end

		def gigya_api_key(val = nil)
			return (@gigya_api_key || Gigya::Connection.shared_connection.api_key) if val.nil?
			@gigya_api_key = val
		end
	end
end
