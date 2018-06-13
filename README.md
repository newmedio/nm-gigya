= NM Gigya Connection API

This provides a simple API for accessing Gigya from Ruby/Rails.  
It is especially focused on making JWT authentication using Gigya JWT tokens easier.

To use, just stick your Gigya settings in config/secrets.yml:

* gigya_api_key
* gigya_user_key
* gigya_user_secret

Then, access the connection object by doing:

  require "gigya"
  conn = Gigya::Connection.shared_connection

Then you can do gigya calls:

  conn.api_get("accounts", "getAccountInfo", {:UID => "asdkjddfsakjl"})

If your API is using JWT authentication, just add this to your controller:

  before_action :gigya_user_required

Then you can access their Gigya UID by doing "gigya_user_identifier".
Other JWT information can be found by doing "gigya_user_information['whatever']"

There is also an experimental dynamic API.

  conn.accounts.getJWTPublicKey.n
