class MarketOrderCleanupWorker
  include Sidekiq::Job

  def perform
    MarketOrder.purge_old_data
  end
end