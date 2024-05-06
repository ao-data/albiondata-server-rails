Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV['RACKATTACK_REDIS_URL'])

Rack::Attack.throttle("pow/1m", limit: ENV['THROTTLE_POW_1MIN'].to_i, period: 1.minute) do |req|
  if req.path == '/pow'
    req.ip
  end
end

Rack::Attack.throttle('pow/1h', limit: ENV['THROTTLE_POW_1HOUR'].to_i, period: 1.hour) do |req|
  if req.path == '/pow'
    req.ip
  end
end

Rack::Attack.throttle('pow/1d', limit: ENV['THROTTLE_POW_1DAY'].to_i, period: 1.day) do |req|
  if req.path == '/pow'
    req.ip
  end
end

Rack::Attack.throttle('apiv2/1m', limit: ENV['THROTTLE_API_1MIN'].to_i, period: 1.minute) do |req|
  if req.path.start_with?('/api/v2/')
    req.ip
  end
end

Rack::Attack.throttle('apiv2/5m', limit: ENV['THROTTLE_API_5MIN'].to_i, period: 5.minutes) do |req|
  if req.path.start_with?('/api/v2/')
    req.ip
  end
end

