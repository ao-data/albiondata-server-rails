class MarketHistoryProcessorWorker
  include Sidekiq::Job

  def perform(data)
    data = JSON.parse(data)
    MarketHistoryProcessorService.process(data)
  end
end