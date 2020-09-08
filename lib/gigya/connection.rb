require "openssl"
require "httparty"
require "jwt"
require "json"
require "securerandom"

# Required for the dynamic modules
#require "active_support"
#require "active_support/core_ext"

module Gigya
	class GigyaApiException < StandardError
		def initialize(msg, result)
			super(msg)
			@api_result = result
		end

		def api_result
			@api_result
		end
	end

	class GigyaDynamicImplementation
		attr_accessor :connection, :area, :function, :data_results, :data_keys

		def clone_gdi
			gdi = GigyaDynamicImplementation.new
			gdi.connection = connection
			gdi.area = area
			gdi.function = function
			gdi.data_results = data_results
			gdi.data_keys = (data_keys || []).clone

			return gdi
		end

		def gdi_value
			current_result = data_results
			data_keys.each do |k|
				current_result = current_result[k]
				return nil if current_result == nil
			end
			return current_result
		end

		def to_h
			gdi_value
		end

		def to_hash
			gdi_value
		end

		def to_value
			gdi_value
		end

		def nil?
			to_value.nil?
		end

		def blank?
			to_value.blank?
		end

		def empty?
			to_value.empty?
		end

		def method_missing(name, *args, &block)
			name = name.to_s
			gdi = clone_gdi

			if data_results == nil
				if(name[-1..-1] == "=" && args.size == 1)
					field_name = name[0..-2]

					if self.area == nil
						raise "Can't run a setter on #{area}"
					else
						function_name = "set" + field_name.camelize
						return connection.api_get(area, function_name, val)
					end
				elsif args.size == 0
					field_name = name
					function_name = "get" + field_name.camelize
					results = connection.api_get(area, function_name)
					gdi.function = function_name
					gdi.data_results = results
					gdi.data_keys = []

					return gdi
				end
			else
				field_name = name
				if field_name[-1..-1] == "="
					field_name = field_name[0..-2]
					if field_name[0..1] == "__"
						field_name = field_name[2..-1]
					else
						field_name = field_name.camelize(:lower)
					end
					setter_hash = {}
					cur_hashpoint = setter_hash
					curval = gdi.data_results
					gdi.data_keys.each do |k|
						curval = curval[k]
						if Hash === curval
							cur_hashpoint[k] = {}
							cur_hashpoint = cur_hashpoint[k]
						elsif Array === curval
							cur_hashpoint[k] = []
							cur_hashpoint = cur_hashpoint[k]
						else
							cur_hashpoint[k] = curval
							cur_hashpoint = curval
						end
					end
					cur_hashpoint[field_name] = args[0]
					setter_hash.keys.each do |k|
						val = setter_hash[k]
						if Hash === val || Array === val
							val = val.to_json
							setter_hash[k] = val
						end
					end

					return connection.api_get(area, function.gsub(/^get/, "set"), setter_hash)
				else
					if field_name[0..1] == "__" 
						# This is an escape sequence to maintain capitalization
						field_name = field_name[2..-1]
					else
						field_name = field_name.camelize(:lower) 
					end
					gdi.data_keys.push(field_name) 

					val = gdi.to_value
					if Hash === val || Array === val || val == nil
						return gdi
					else
						return val
					end
				end
			end

			super
		end

		# Don't know if I should implement this
		# respond_to_missing?(method_name, *args)
	end

	class Connection
		attr_accessor :jwt_skip_validation
		attr_accessor :whitelisted_api_keys

		GIGYA_BASE_URL="gigya.com"
		def self.shared_connection
			@@connection ||= begin
				conn = self.new(
					:datacenter => ENV["GIGYA_DATACENTER"] || "us1",
					:api_key => ENV["GIGYA_API_KEY"],
					:user_key => ENV["GIGYA_USER_KEY"],
					:user_secret => ENV["GIGYA_USER_SECRET"],
					:debug_connection => ENV["GIGYA_DEBUG_CONNECTION"] == "1"
				)

				whitelist = ENV["GIGYA_WHITELISTED_API_KEYS"]
				conn.whitelisted_api_keys => whitelist.split(",") unless whitelist.blank?

				conn.jwt_skip_validation = false
				conn
			end

			return @@connection
		end

		def self.shared_connection=(conn)
			@@connection = conn
		end

		# The regular URI.encode doesn't do "+"s, so this is a shortcut
		def self.encode(x)
			URI.encode_www_form_component(x)
		end

		# See here for the reasons for the strange reasons for this strange function:
		# https://developers.gigya.com/display/GD/How+To+Validate+A+Gigya+id_token
		# Seems to apply to some, but not all, pieces of Base64 encoded things.
		def self.strange_munge(x)
			x.gsub("-", "+").gsub("_", "/")
		end

		def self.strange_unmunge(x)
			x.gsub("+", "-").gsub("/", "_")
		end

		# According to https://developers.gigya.com/display/GD/How+To+Validate+A+Gigya+id_token 
		# Gigya JWTs are not in the standard format, but must be munged first
		def self.reformat_jwt(jwt_token)
			signable_piece = jwt_token.split(".")[0..1].join(".")
			signature = strange_munge(jwt_token.split(".")[2])
			return [signable_piece, signature].join(".")
		end

		# Builds an OpenSSL RSA key from a given modulus and exponent.
		# This is because Gigya likes to give us keys like this.
		# https://stackoverflow.com/questions/46121275/ruby-rsa-from-exponent-and-modulus-strings
		def self.build_rsa_key(modulus, exponent)
			mod_num = OpenSSL::BN.new(Base64.decode64(strange_munge(modulus)), 2)
			exp_num = OpenSSL::BN.new(Base64.decode64(exponent), 2)
			k = OpenSSL::PKey::RSA.new
			if k.respond_to? :set_key
				k.set_key(mod_num, exp_num, 0)
			else
				k.n = mod_num
				k.e = exp_num
			end
			return k
		end

		def initialize(opts = {})
			@opts = opts
			@cached_data = {}
		end

		def build_test_jwt(uid = nil, data_options = {}, expiration = nil, gigya_munge = false)
			uid = SecureRandom.uuid if uid.nil?
			data_options = (data_options || {}).dup
			data_options["sub"] = uid 
			data_options["apiKey"] ||= (@opts[:api_key] || "no_api_key")
			data_options["iss"] ||= "https://fidm.gigya.com/jwt/#{data_options["apiKey"]}/"
			data_options["iat"] ||= (Time.now - 10.seconds).to_i
			data_options["exp"] = (Time.now + expiration).to_i unless expiration.nil?
			data_options["exp"] ||= (Time.now + (60 * 60)).to_i
			data_options["firstName"] ||= "Jim#{rand(10000000)}"
			data_options["lastName"] ||= "Jimmersly#{rand(10000000)}"
			data_options["email"] ||= "example+#{uid}@example.com"
			
			jwt_str = JWT.encode(data_options, nil, 'none', {:typ => "JWT"})
			jwt_str = self.class.strange_unmunge(jwt_str) if gigya_munge

			return jwt_str
		end

		def connection_options
			@opts
		end

		# NOTE - the key_id is here so that, in the future, we might be able
		#        to download a specific key.  Right now, it is ignored and the
		#        most recent one is obtained
		def download_latest_jwt_public_key(key_id = nil)
			keyinfo = api_get("accounts", "getJWTPublicKey")
			keyinfo_id = keyinfo["kid"]
			raise "Unsupported Key Type" if keyinfo["kty"] != "RSA"
			keyinfo_key = self.class.build_rsa_key(keyinfo["n"], keyinfo["e"])
			@cached_data["jwt_public_keys"] ||= {}
			@cached_data["jwt_public_keys"][keyinfo_id] = keyinfo_key
			return keyinfo_key
		end

		def validate_jwt(jwt_token, gigya_munge = false)
			jwt_token = self.class.reformat_jwt(jwt_token) if gigya_munge

			user_jwt_info, signing_jwt_info = JWT.decode(jwt_token, nil, false)

			return user_jwt_info if jwt_skip_validation

			# If we have enumerated whitelisted API keys
			unless whitelisted_api_keys.nil?
				# Grab the API key encoded in the token
				jwt_api_key = user_jwt_info["apiKey"]

				# Our own API key is automatically valid
				if jwt_api_key != api_key
					# Make sure it is listed in the whitelisted keys
					raise "Invalid API Key" unless whitelisted_api_keys.include?(jwt_api_key)
				end
			end

			signing_key_id = signing_jwt_info["keyid"]
			@cached_data["jwt_public_keys"] ||= {}
			k = @cached_data["jwt_public_keys"][signing_key_id]
			k = download_latest_jwt_public_key(signing_key_id) if k == nil
			user_jwt_info, signing_jwt_info = JWT.decode(jwt_token, k, true, { :algorithm => signing_jwt_info["alg"] })
			return user_jwt_info
		end

		def api_key
			@opts[:api_key]
		end

		def login(username, password)
			user_info = api_get("accounts", "login", {:loginID => username, :password => password, :targetEnv => "mobile"}, :throw_on_error => true)
			uid = user_info["UID"]
			session_token = user_info["sessionToken"]
			session_secret = user_info["sessionSecret"]
			conn = self.class.new(@opts.merge(:session => {:user_id => uid, :profile => user_info["profile"], :token => session_token, :secret => session_secret}))
			return conn
		end

		def api_get(area, function, params = nil, opts = nil)
			api_call("GET", area, function, params, opts)
		end

		def api_post(area, function, params = nil, opts = nil)
			api_call("POST", area, function, params, opts)
		end

		# This allows substituting how HTTP calls are made (could be useful for testing)
		def http_driver
			@http_driver || HTTParty
		end

		def http_driver=(val)
			@http_driver = val
		end

		def api_call(http_method, area, function, params = nil, opts = nil)
			params ||= {}
			opts ||= {}
			opts = @opts.merge(opts)
		
			base_url = "https://#{area}.#{opts[:datacenter]}.#{GIGYA_BASE_URL}/#{area}.#{function}"

			params[:apiKey] = opts[:api_key]
			unless opts[:authenticate_app] == false
				params[:secret] = opts[:user_secret]
				params[:userKey] = opts[:user_key] unless opts[:user_key].blank?
			end

			if opts[:session] != nil
				if opts[:session][:user_id] != nil
					unless opts[:ignore_user_id] 
						params[:UID] = opts[:session][:user_id]
					end
				end
			end

			if opts[:debug_connection] 
				# FIXME - what to do with logging
				puts "DEBUG CONNECTION SEND: #{http_method} #{base_url} // #{params.inspect}"
			end
			http_response = nil
			response = begin
				http_response = http_method == "GET" ? http_driver.get(base_url, :query => params) : http_driver.post(base_url, :body => params)
				JSON.parse(http_response.body)
			rescue
				{"errorCode" => 600, "errorMessage" => "Unknown error", "errorDetail" => "Unable to communicate with authentication server", :http => http_response.inspect}
			end

			if opts[:debug_connection]
				# FIXME - what to do with logging
				puts "DEBUG CONNECTION RECEIVE: #{response.inspect}"
			end

			if opts[:throw_on_error]
				if response["statusCode"].to_i >= 400 || response["errorCode"].to_i > 0
					error_msg = "#{response["errorMessage"]}: #{response["errorDetails"]}"
					raise GigyaApiException.new(error_msg, response)
				end
			end

			return response
		end

		def lookup_user(uid)
			Gigya::User.find(uid, :connection => self)
		end
	
		def method_missing(name, *args, &block)
			if args.size == 0
				gdi = GigyaDynamicImplementation.new
				gdi.connection = self
				gdi.area = name
				return gdi
			else
				super
			end
		end

		# Don't know if I should implement this
		# respond_to_missing?(method_name, *args)
	end
end
