# sidekiq
require 'sidekiq'
require 'sidekiq-cron'
require 'sidekiq/web'

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['SIDEKIQ_REDIS_URL'] }
end

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['SIDEKIQ_REDIS_URL'] }
end

Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
  Rack::Utils.secure_compare(::Digest::SHA256.hexdigest(user), ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_WEB_USER'])) &
    Rack::Utils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_WEB_PASS']))
end


cron_jobs = [
  {
    'name'  => 'marketorder-cleanup-west',
    'class' => 'MarketOrderCleanupWorker',
    'cron'  => '5 * * * *',
    'args'  => 'west',
    'queue' => 'low'
  },
  {
    'name' => ' markethistory-cleanup-west',
    'class' => 'MarketHistoryCleanupWorker',
    'cron'  => '10 * * * *',
    'args'  => 'west',
    'queue' => 'low'
  },
  {
    'name'  => 'marketorder-cleanup-east',
    'class' => 'MarketOrderCleanupWorker',
    'cron'  => '15 * * * *',
    'args'  => 'east',
    'queue' => 'low'
  },
  {
    'name' => ' markethistory-cleanup-east',
    'class' => 'MarketHistoryCleanupWorker',
    'cron'  => '20 * * * *',
    'args'  => 'east',
    'queue' => 'low'
  },
  {
    'name'  => 'marketorder-cleanup-europe',
    'class' => 'MarketOrderCleanupWorker',
    'cron'  => '25 * * * *',
    'args'  => 'europe',
    'queue' => 'low'
  },
  {
    'name' => ' markethistory-cleanup-europe',
    'class' => 'MarketHistoryCleanupWorker',
    'cron'  => '30 * * * *',
    'args'  => 'europe',
    'queue' => 'low'
  },
  {
    'name' => ' albion-online-update-check',
    'class' => 'AlbionOnlineUpdateCheckWorker',
    'cron'  => '*/30 * * * *',
    'queue' => 'low'
  },
]

# Gameinfo polling is opt-in, since its jobs need a RUN_MODE=sidekiq_gameinfo process to work the gameinfo
# queue. GAMEINFO_ENABLED=true adds the jobs and GAMEINFO_ENABLED=false removes them (load_from_array keeps
# jobs that are no longer listed). Left unset, a container does not remove the jobs another container added.
gameinfo_cron_jobs = %w[west east europe].flat_map do |server_id|
  [
    {
      'name'  => "kill-event-poll-#{server_id}",
      'class' => 'KillEventPollWorker',
      'cron'  => ENV.fetch('GAMEINFO_EVENTS_CRON', '* * * * *'),
      'args'  => server_id,
      'queue' => 'gameinfo'
    },
    {
      'name'  => "battle-poll-#{server_id}",
      'class' => 'BattlePollWorker',
      'cron'  => ENV.fetch('GAMEINFO_BATTLES_CRON', '*/3 * * * *'),
      'args'  => server_id,
      'queue' => 'gameinfo'
    },
  ]
end

unless ENV['SECRET_KEY_BASE_DUMMY']
  Sidekiq::Cron::Job.load_from_array(cron_jobs)

  case ENV['GAMEINFO_ENABLED']
  when 'true' then Sidekiq::Cron::Job.load_from_array(gameinfo_cron_jobs)
  when 'false' then gameinfo_cron_jobs.each { |job| Sidekiq::Cron::Job.destroy(job['name']) }
  end
end
