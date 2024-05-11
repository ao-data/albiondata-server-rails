# sidekiq
require 'sidekiq'
require 'sidekiq-cron'
require 'sidekiq/web'

Sidekiq.configure_client do |config|
  config.redis = { url: "redis://#{ENV['SIDEKIQ_REDIS_HOST']}:#{ENV['SIDEKIQ_REDIS_PORT']}/#{ENV['SIDEKIQ_REDIS_DB']}" }
end

Sidekiq.configure_server do |config|
  config.redis = { url: "redis://#{ENV['SIDEKIQ_REDIS_HOST']}:#{ENV['SIDEKIQ_REDIS_PORT']}/#{ENV['SIDEKIQ_REDIS_DB']}" }
end

Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
  Rack::Utils.secure_compare(::Digest::SHA256.hexdigest(user), ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_WEB_USER'])) &
    Rack::Utils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_WEB_PASS']))
end


cron_jobs = [
  {
    'name'  => 'MarketOrder Cleanup West',
    'class' => 'MarketOrderCleanupWorker',
    'cron'  => '*/5 * * * *',
    'args'  => 'west',
    'queue' => 'low'
  },
  {
    'name' => ' MarketHistory Cleanup West',
    'class' => 'MarketHistoryCleanupWorker',
    'cron'  => '*/5 * * * *',
    'args'  => 'west',
    'queue' => 'low'
  },
  {
    'name'  => 'MarketOrder Cleanup East',
    'class' => 'MarketOrderCleanupWorker',
    'cron'  => '*/5 * * * *',
    'args'  => 'east',
    'queue' => 'low'
  },
  {
    'name' => ' MarketHistory Cleanup East',
    'class' => 'MarketHistoryCleanupWorker',
    'cron'  => '*/5 * * * *',
    'args'  => 'east',
    'queue' => 'low'
  },
  {
    'name'  => 'MarketOrder Cleanup Europe',
    'class' => 'MarketOrderCleanupWorker',
    'cron'  => '*/5 * * * *',
    'args'  => 'europe',
    'queue' => 'low'
  },
  {
    'name' => ' MarketHistory Cleanup Europe',
    'class' => 'MarketHistoryCleanupWorker',
    'cron'  => '*/5 * * * *',
    'args'  => 'europe',
    'queue' => 'low'
  },
]

#
# # {
# #   'name' => 'MarketHistory Monthly Exporter',
# #   'class' => 'MarketHistoryMonthlyExporterWorker',
# #   'cron'  => '*/5 * * * *',
# #   'queue' => 'low'
# # }
#
Sidekiq::Cron::Job.load_from_array(cron_jobs) unless ENV['SECRET_KEY_BASE_DUMMY']
