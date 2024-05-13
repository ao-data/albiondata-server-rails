class MarketOrderDedupeWorker
  include Sidekiq::Job

  def perform(data, server_id)
    data = JSON.parse(data)
    MarketOrderDedupeService.new(data, server_id).process
  end
end