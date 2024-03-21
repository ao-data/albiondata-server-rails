
class MarketHistoryDedupeWorker
  include Sidekiq::Job

  def perform(data)
    data = JSON.parse(data)
    MarketHistoryDedupeService.dedupe(data)
  end
end