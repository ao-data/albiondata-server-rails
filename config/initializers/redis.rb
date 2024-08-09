WEST_REDIS = Redis.new(url: ENV['REDIS_WEST_URL'])
EAST_REDIS = Redis.new(url: ENV['REDIS_EAST_URL'])
EUROPE_REDIS = Redis.new(url: ENV['REDIS_EUROPE_URL'])
IDENTIFIER_REDIS = Redis.new(url: ENV['REDIS_IDENTIFIER_URL'])

REDIS = { 'west' => WEST_REDIS, 'east' => EAST_REDIS, 'europe' => EUROPE_REDIS, 'identifier' => IDENTIFIER_REDIS }
