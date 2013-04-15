# DynamoStore — session storage in AWS DynamoDB for Rails apps

A drop-in replacement for Rails' built-in CookieStore and ActiveRecord session storage options using the AWS DynamoDB database service.

Storing session data in cookies can be bad for a number of reasons: depending on the type of data, it can be a security concern, and the size is limited to 4KB, which can be a problem for some use cases where lots of data needs to be kept, such as the contents of a large shopping cart. Therefore storing sessions in the database makes sense, however using the app database with ActiveRecord can be painfully slow. DynamoDB is meant to be an alternative for Memcache with persistence.

Personal note: I've successfully implemented this on a busy e-commerce app some months ago, but after launch we noticed some shortcomings in DynamoDB that I would consider a deal-breaker today. As of writing (04/2013) DynamoDB still has no way of deleting items with a single query, that is, a single API call. When using DynamoDB for session storage, of course there should be a cron of some kind to clean out old session entries. Using DynamoDB's current API, you first need to batch-iterate over all entries in the DB to identify the old ones, then run separate queries to delete those. In our case, this took several hours every night, causing ridiculous server load and costs for API calls.


## How to use

Create a new table in DynamoDB where the sessions will be stored. Hash key should be 'session_id' (String)

Add the AWS-SDK gem to your Gemfile:

    gem 'aws-sdk'

Copy ```dynamo_store.rb``` to the ```lib``` directory. Edit the file to match your AWS credentials and setup. Also change the table name and session_id field if that's different in your setup.

Edit ```config/initializers/session_store.rb``` and change:

    config.session_store :dynamo_store

Restart your web server.


## Copyright & License

Copyright (c) 2013 Matthias Siegel.
See [LICENSE](https://github.com/matthiassiegel/dynamo-storage/tree/master/LICENSE.md) for details.