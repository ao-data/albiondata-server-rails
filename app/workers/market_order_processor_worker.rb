class MarketOrderProcessorWorker
  include Sidekiq::Job

  def perform(data)
    data = JSON.parse(data)
    MarketOrderProcessorService.new(data).process
  end
end