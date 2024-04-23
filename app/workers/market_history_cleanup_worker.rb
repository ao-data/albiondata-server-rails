class MarketHistoryCleanupWorker
  include Sidekiq::Job
  sidekiq_options queue: :low

  def perform(server_id)
    Multidb.use(server_id.to_sym) do
      MarketHistory.purge_old_data
    end
  end
end