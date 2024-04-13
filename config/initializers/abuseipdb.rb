require 'abuseipdb'

Abuseipdb.configure do |config|
  config.timeout = 5
  config.api_key = ENV['ABUSEIPDB_API_KEY']
end
