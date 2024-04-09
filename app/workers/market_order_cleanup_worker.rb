class MarketOrderCleanupWorker
  include Sidekiq::Job
  sidekiq_options queue: :low

  def perform
    MarketOrder.purge_old_data
  end
end