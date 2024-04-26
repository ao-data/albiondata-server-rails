
class MarketHistoryDedupeWorker
  include Sidekiq::Job

  def perform(data, server_id)
    data = JSON.parse(data)
    MarketHistoryDedupeService.new.dedupe(data, server_id)
  end
end