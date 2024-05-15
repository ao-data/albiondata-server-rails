require 'abuseipdb'

Abuseipdb.configure do |config|
  config.timeout = 5
  config.api_key = ENV['ABUSEIPDB_API_KEY']
end

ABUSEIPDB_REDIS = Redis.new(url: ENV['ABUSEIPDB_REDIS_URL']) unless ENV['ABUSEIPDB_REDIS_URL'].nil?
