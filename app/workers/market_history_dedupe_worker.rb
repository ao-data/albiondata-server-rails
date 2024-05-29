
class MarketHistoryDedupeWorker
  include Sidekiq::Job

  def perform(data, server_id, opts)
    data = JSON.parse(data)
    opts = JSON.parse(opts)
    MarketHistoryDedupeService.new.dedupe(data, server_id, opts)
  end
end