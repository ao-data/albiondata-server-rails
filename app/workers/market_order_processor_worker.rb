class MarketOrderProcessorWorker
  include Sidekiq::Job

  def perform(data, server_id)
    data = JSON.parse(data)
    MarketOrderProcessorService.new(data, server_id).process
  end
end