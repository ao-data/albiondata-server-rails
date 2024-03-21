class MarketOrderDedupeWorker
  include Sidekiq::Job

  def perform(data)
    data = JSON.parse(data)
    MarketOrderDedupeService.new(data).process
  end
end