class MarketHistoryCleanupWorker
  include Sidekiq::Job

  def perform
    MarketHistory.purge_old_data
  end
end