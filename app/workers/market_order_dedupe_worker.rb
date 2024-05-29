class MarketOrderDedupeWorker
  include Sidekiq::Job

  def perform(data, server_id, opts)
    data = JSON.parse(data)
    opts = JSON.parse(opts)

    MarketOrderDedupeService.new(data, server_id, opts).process
  end
end