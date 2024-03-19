# sidekiq
Sidekiq.configure_client do |config|
  config.redis = { url: "redis://#{ENV['SIDEKIQ_REDIS_HOST']}:#{ENV['SIDEKIQ_REDIS_PORT']}/#{ENV['SIDEKIQ_REDIS_DB']}" }
end

Sidekiq.configure_server do |config|
  config.redis = { url: "redis://#{ENV['SIDEKIQ_REDIS_HOST']}:#{ENV['SIDEKIQ_REDIS_PORT']}/#{ENV['SIDEKIQ_REDIS_DB']}" }
end

# Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
#   Rack::Utils.secure_compare(::Digest::SHA256.hexdigest(user), ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_WEB_USER'])) &
#     Rack::Utils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_WEB_PASS']))
# end
