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

Rack::Attack.throttle('apiv2-non-gzip/1h', limit: 6, period: 1.minute) do |req|
  if req.path.start_with?('/api/v2/')
    if !req.env.include?('HTTP_ACCEPT_ENCODING') || (req.env['HTTP_ACCEPT_ENCODING'].split(',') & ['gzip', 'deflate', 'br', 'zstd']).size == 0
      req.ip
    end
  end
end

Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env['rack.attack.match_data']
  now = match_data[:epoch_time]

  headers = {
    'RateLimit-Limit' => match_data[:limit].to_s,
    'RateLimit-Remaining' => '0',
    'RateLimit-Reset' => (now + (match_data[:period] - now % match_data[:period])).to_s
  }

  if request.env['rack.attack.matched'] == 'apiv2-non-gzip/1h'
    [ 429, headers, ["Throttled, be nice to the server, use compression (gzip, deflate, etc)! Throttle resets at #{Time.at(now + (match_data[:period] - now % match_data[:period]))}!\n"]]
  else
    [ 429, headers, ["Throttled, slow down!\n"]]
  end
end

