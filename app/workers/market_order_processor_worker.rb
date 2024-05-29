class MarketOrderProcessorWorker
  include Sidekiq::Job

  def perform(data, server_id, opts)
    data = JSON.parse(data)
    opts = JSON.parse(opts)
    MarketOrderProcessorService.new(data, server_id, opts).process
  end
end