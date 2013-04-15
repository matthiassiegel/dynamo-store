# encoding: utf-8

require 'aws'
require 'base64'

#
# Rails session store for Amazon DynamoDB.
#
# Requires the aws-sdk gem.
#
# Set this in config/initializers/session_store.rb:
#
#    config.session_store :dynamo_store
#
# ActionDispatch::Session::AbstractStore inherits from Rack::Session::Abstract::ID which
# is a good place to look for the methods we need to implement here.
#
#    See: http://stackoverflow.com/questions/6909295/how-to-build-your-own-custom-session-store-class
#         https://github.com/rack/rack/blob/master/lib/rack/session/abstract/id.rb
#
class DynamoStore < ActionDispatch::Session::AbstractStore
  
  @@config = {
    :access_key_id => ENV['AWS_ACCESS_KEY_ID'],
    :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
    :dynamo_db_endpoint => 'dynamodb.us-west-1.amazonaws.com',
    :use_ssl => true
  }
  @@table = 'Sessions'
  
  attr_accessor :sessions
  
  
  #
  # All thread safety and session retrival proceedures should occur here.
  # Should return [session_id, session_data].
  # If nil is provided as the session_id, generation of a new valid id should occur within.
  #
  def get_session(env, session_id)
    session_id ||= generate_sid
    
    sessions ||= AWS::DynamoDB.new(@@config).tables[@@table]
    sessions.hash_key = [:session_id, :string]
    
    #
    # If session doesn't exist (yet), prevent crash here and continue with a fresh session
    #
    begin
      session_data = sessions.items[session_id].attributes[:session_data]
      
      if session_data.blank?
        session_data = {}
      else
        session_data = Base64.decode64(session_data)
        session_data = ::Marshal.load(session_data)
      end
    rescue Exception => e
      session_data = {}
    end
    
    [session_id, session_data]
  end
  
  
  #
  # All thread safety and session storage proceedures should occur here.
  # Should return true or false dependant on whether or not the session was saved or not.
  #
  # Primary key for each record is 'session_id' (S = String), the entire session hash goes into 'session_data'.
  # We store an 'updated_at' timestamp so we can use a cron job to remove old sessions after a certain time.
  #
  def set_session(env, session_id, session_data, options = {})
    sessions ||= AWS::DynamoDB.new(@@config).tables[@@table]
    sessions.hash_key = [:session_id, :string]
    
    session_data = Base64.encode64(::Marshal.dump(session_data))
    
    begin
      sessions.items.put(:session_id => session_id, :session_data => session_data, :updated_at => Time.now.to_i)
    rescue Exception => e
    end
    
    session_id
  end
  
  
  #
  # All thread safety and session destroy proceedures should occur here.
  # Should return a new session_id or nil if options[:drop]
  #
  # Note: This method is only used in newer versions of Rack
  #
  def destroy_session(env, session_id, options = {})
    sessions ||= AWS::DynamoDB.new(@@config).tables[@@table]
    sessions.hash_key = [:session_id, :string]
    
    begin
      sessions.items[session_id].delete
    rescue Exception => e
    end
    
    return (options[:drop].nil? ? generate_sid : nil)
  end
  
  #
  # Needed for older versions of Rack ~1.2.5
  #
  def destroy(env)
    sessions ||= AWS::DynamoDB.new(@@config).tables[@@table]
    sessions.hash_key = [:session_id, :string]
    
    begin
      sessions.items[env['HTTP_COOKIE']].delete
    rescue Exception => e
    end
    
    return generate_sid    
  end
  
end