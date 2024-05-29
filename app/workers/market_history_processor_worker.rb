class MarketHistoryProcessorWorker
  include Sidekiq::Job

  def perform(data, server_id, opts)
    data = JSON.parse(data)
    opts = JSON.parse(opts)
    MarketHistoryProcessorService.new.process(data, server_id, opts)
  end
end