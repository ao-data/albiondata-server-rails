class MarketHistoryCleanupWorker
  include Sidekiq::Job
  sidekiq_options queue: :low

  def perform(server_id, weekly_cleanup = true)
    Multidb.use(server_id.to_sym) do
      if weekly_cleanup
        MarketHistory.purge_weekly_data
      else
        MarketHistory.purge_older_data
      end
    end
  end
end