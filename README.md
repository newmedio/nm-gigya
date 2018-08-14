# Gigya API Connection Utilities

This gem provides Ruby utilities for accessing the Gigya API from Ruby || Rails. It is especially focused on making the Gigya JSON Web Token(JWT) authentication easier.

## Installation and Configuration

To install, just stick it in your Gemfile

```
gem "nm-gigya", :require => "gigya"
```

The "require" is not required, but if you don't use it you will need to require it in your main stuff.

Define your Gigya credentials using the following environment variable keys:

* gigya_api_key
* gigya_user_key
* gigya_user_secret

NOTE - apparently Rails 5.2 deprecated config/secrets.yml.  If you don't want to use config/secrets.yml, you can just create the connection and set it to be the shared connection.
```
Gigya::Connection.shared_connection = Gigya::Connection.new(:api_key => "apikey", :user_key => "userkey", :user_secret => "usersecret")
```

## Basic Usage

Then, access the connection object by doing:

```
  connection = Gigya::Connection.shared_connection
```

Now, you can call the Gigya API

```
  connection.api_get("accounts", "getAccountInfo", {:UID => "XXXXXXXX"})
```

If your API is using JWT authentication, simply add this to your controller:

```
  include Gigya::ControllerUtils
  before_action :gigya_user_required
```

You should now have access the user's Gigya UID with `gigya_user_identifier`.
Other JWT information can be found with `gigya_user_information['key']`.

You can also include this in your helpers for the same effect.

## More JWT Magic

Additionally, if you need to store the JWT token in some other way (like in a cookie, param, or session), you can do "gigya_save_jwt(:cookie or :session)" (defaults to :cookie) and it will do so.  gigya_user_required/gigya_user_identifier checks tokens in the following order:

1. First priority is in the Authorization: HTTP header.
2. Next, the query params are checked.  By default we look in the gigya_token param (settable with Gigya::ControllerUtils::GIGYA_QUERY_PARAM)
3. Then, we check cookies.  Again, gigya_token is the default (settable with Gigya::ControllerUtils::GIGYA_COOKIE_PARAM)
4. Finaly, we check the session.  Again, gigya_token is the default (settable with Gigya::ControllerUtils::GIGYA_COOKIE_PARAM)

Basically, the order is in one of intentionality.  Anything the browser sends is more specifically intentional than what we are storing for them.  The authorization Header has the highest priority, then URL query params, and then cookies (which might be stale, etc.).

If you need to get your JWT in a custom way, just do Gigya::Connection.shared_connection.validate_jwt(the_token)

## Integrating with your web app

### Getting the JWT to your application

Sometimes you need the JWT for authentication in a web app, in which case you can't set the Authorization header.  
In that case, I would (a) do the login, (b) obtain the JWT, (c) create/call an action to save the JWT to a cookie or session parameter using gigya_save_jwt.

To authenticate within an action, create a before_filter like this (put in your ApplicationController):

```
def user_required
	begin
		raise "Invalid User" if gigya_user_identifier.blank?
	rescue
		redirect_to whever_you_login_from_path
	end
end
```

Then you can just add "before_action :user_required" in the controllers that need a user.

### Using a Gigya Authentication Screenset

I also implemented a way to very simply and easily utilize a Gigya screenset for login.  
All you have to do is create a session controller and include a particular class.

It looks like this:
```
class SessionsController < ApplicationController
	include Gigya::Session

	gigya_screen_set "WhateverScreenSetIWantToUse"
	gigya_after_login_redirect :whatever_path
end
```
Then you just need to add `resource :session` to your routes file.
Those are the typical parameters to use.
This will manage (a) showing the Gigya login screenset, (b) saving a JWT after login, and (c) redirecting you back into the application afterwards.
The endpoint for this particular one is `/session/new`. 
You can pass it a redirect param if you want it to redirect somewhere else after successful login, so `/session/new?redirect=/wherever`.

If you leave off the `gigya_screen_set` command it will default to "Default-RegistrationLogin" which I think is Gigya's own screenset. 
If you leave off `gigya_after_login_redirect` it will default to `root_path`.  
That function can be given a string (which it will use directly), a symbol (which it will then "send" to "self"), or a Proc (which it call .call()").
Other functions which can be used to set settings on this thing include `gigya_start_screen`, `gigya_token_storage` (:cookie, :session - defaults to session I wouldn't change it yet in this version), `gigya_script_content_for` (by default we just shove the JS into the page, but this allows you to specify a content_for block to shove it into), `gigya_token_expire_time` (defaults to 24.hours), `gigya_jwt_fields` (comma-separated list of fields for Gigya to put in the JWT.  Defaults to "firstName,lastName,email"), `gigya_api_key` (defaults to the one from the shared_connection object).

## Using JWTs in testing

When testing, you can skip the validation testing for the JWTs.
First, turn off the JWT testing for the JWT verifier:
```
Gigya::Connection.shared_connection.jwt_skip_validation = true
```

Next, generate a JWT token for use in testing:

```
jwt = Gigya::Connection.shared_connection.build_test_jwt
```

With JWT validation turned off, you can use this JWT token.
If you want to specify stuff to put into your JWT, the parameters are `build_test_jwt(uid, data_options, expiration)`.
So, for the user "1234", with the fields "firstName", "lastName", "email", and "data.whatever", which expires in 3 hours, we would call

```
jwt = Gigya::Connection.shared_connection.build_test_jwt("1234", {"firstName" => "Jim", "lastName" => "Jimmersly", "email" => "jim@example.com"}, 3.hours)
```

You can see the results by doing the validation:

```
info = Gigya::Connection.shared_connection.validate_jwt(jwt)
```

If no information is specified, a token for a randomized user is present (each call to to build_test_jwt should result in a different user) using standard Gigya parameters.

## Refresh Tokens ##

If there is some amount of risk on your login---i.e., that you want to make sure the person gets logged off, even before their session expires, we support that using refresh tokens.

In this system, your original token *is* your refresh token.  You merely specify how long you want to wait until we do a refresh token check.  So, if your token is for 1 day, you might refresh it every 15 minutes.
To do that, just set the following in an initializer:

```
Gigya::ControllerUtils.gigya_jwt_refresh_time = 15.minutes
```

This will cause a refresh of authentication whenever the token is 15 minutes old.
The final expiration time will still be the same, more-or-less. 
There is some jitter due to the time it takes for network traffic.
So you will probably gain a second or two from your expiration date every time the token is refreshed.

The refresh process is automatic for cookie and session authentication.
If you are authenticating with an `Authorization` header, you will be returned a `X-Set-Authorization-Token` header with the new JWT in it.
Additionally, the `X-Set-Authorization-Token-Expiration` header will have the new expiration time of the token.
If you fail to use the new JWT, it will slow your app down by doing re-auths every time.

You can also customize the refresh process if you have additional internal logic you need to apply.
You can adjust the token refreshing rules by overriding `needs_token_refresh?` in your controller.  
Call `needs_token_refresh_for_time?` to get the existing time-based refresh logic.

You can then override the actual refresh logic by overriding `perform_token_refresh` in your controller.  Call `gigya_perform_token_refresh` to get the existing gigya code for performing a refresh.
This way, if there are additional exceptional circumstances which will require throwing errors, you can do that here.

For instance:
```
class MyController < ApplicationController::Base
	include Gigya::ControllerUtils
	before_action :user_required

	def needs_token_refresh?
		if Time.now.wday == 0
			# Refresh every request on Sunday
			return true
		else
			# Otherwise do the normal rules
			return needs_token_refresh_for_time?
		end
	end

	def perform_token_refresh
		if is_in_jerk_list(gigya_user_identifier)
			# deny access to jerks
			raise "You're a jerk" 
		else
			# otherwise do a normal refresh
			gigya_perform_token_refresh
		end
	end

	def user_required
		begin
			raise "Invalid User" if gigya_user_identifier.blank?
		rescue
			redirect_to whever_you_login_from_path
		end
	end
end
```

## User Object

We have added a Gigya::User object to simplify handling of users.
We recommend that you subclass this object for your own usage.
Basically, it is a simple wrapper around getAccountInfo and setAccountInfo which also incorporates some caching if you are using Rails.

```
u = Gigya::User.find("abc123")
u.uid # abc123
u.created_at
u.first_name
u.last_name
u.full_name
u.email
u.birthday
u.gender
u.gender_string
u.gigya_details # All the details from getAccountInfo as a hash
u.save

u2 = Gigya::User.find("abc123") # results are from cache
u2.reload # Reloads using getAccountInfo

u3 = Gigya::User.find_by_email("me@example.com") # loads a user by email. Experimental.
```

If you want to use a specific connection instead of the shared connection, do either:

```
u = conn.lookup_user("abc123")
# or
u = Gigya::User.find("abc123", :connection => conn)
```

We recommend you implement a custom class to take care of any customizations for this:

```
class MyUser < Gigya::User
  def my_custom_detail
    gigya_details["data"]["mystuff"] rescue nil
  end

  def my_custom_detail=(val)
    gigya_details["data"] ||= {}
    gigya_details["data"]["mystuff"] = val
  end
end

u = MyUser.find("abc123")
u.my_custom_detail = "blah"
u.save
```

You can set caching options using

```
Gigya::User.cache_options = { :expires_in => 1.hour }
```

Note that changes to the user object aren't cached until `save` is called.

## Experimental Dynamic API

There is also an experimental dynamic API.

```
  conn.accounts.JWTPublicKey.n
```
