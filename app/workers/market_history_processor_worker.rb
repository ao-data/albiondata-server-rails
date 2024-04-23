class MarketHistoryProcessorWorker
  include Sidekiq::Job

  def perform(data, server_id)
    data = JSON.parse(data)
    MarketHistoryProcessorService.process(data, server_id)
  end
end