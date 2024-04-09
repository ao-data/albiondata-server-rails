class MarketHistoryCleanupWorker
  include Sidekiq::Job
  sidekiq_options queue: :low

  def perform
    MarketHistory.purge_old_data
  end
end