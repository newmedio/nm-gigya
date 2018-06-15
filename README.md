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

## More JWT Magic

Additionally, if you need to store the JWT token in some other way (like in a cookie, param, or session), you can do "gigya_save_jwt(:cookie or :session)" (defaults to :cookie) and it will do so.  gigya_user_required/gigya_user_identifier checks tokens in the following order:

1. First priority is in the Authorization: HTTP header.
2. Next, the query params are checked.  By default we look in the gigya_token param (settable with Gigya::ControllerUtils::GIGYA_QUERY_PARAM)
3. Then, we check cookies.  Again, gigya_token is the default (settable with Gigya::ControllerUtils::GIGYA_COOKIE_PARAM)
4. Finaly, we check the session.  Again, gigya_token is the default (settable with Gigya::ControllerUtils::GIGYA_COOKIE_PARAM)

Basically, the order is in one of intentionality.  Anything the browser sends is more specifically intentional than what we are storing for them.  The authorization Header has the highest priority, then URL query params, and then cookies (which might be stale, etc.).

If you need to get your JWT in a custom way, just do Gigya::Connection.shared_connection.validate_jwt(the_token)

## Integrating with your web app

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

## Experimental Dynamic API

There is also an experimental dynamic API.

```
  conn.accounts.JWTPublicKey.n
```
