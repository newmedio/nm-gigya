# Gigya API Connection Utilities

This gem provides Ruby utilities for accessing the Gigya API from Ruby || Rails. It is especially focused on making the Gigya JSON Web Token(JWT) authentication easier.

## Install

In your Gemfile:

`gem 'nm-gigya', :require => "gigya"`

## Usage

Define your Gigya credentials using the following environment variable keys:

* gigya_api_key
* gigya_user_key
* gigya_user_secret

Then, create a connection:

```
  require "gigya"

  connection = Gigya::Connection.shared_connection
```

Now, you can call the Gigya API

```
  connection.api_get("accounts", "getAccountInfo", {:UID => "XXXXXXXX"})
```

If your API is using JWT authentication, simply add this to your controller:

```
  before_action :gigya_user_required
```

You should now have access the user's Gigya UID with `gigya_user_identifier`.
Other JWT information can be found with `gigya_user_information['key']`.

## Experimental

There is also an experimental dynamic API:

```
  conn.accounts.getJWTPublicKey.n
```
