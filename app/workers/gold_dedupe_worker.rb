class GoldDedupeWorker
  include Sidekiq::Worker

  def perform(data)
    data = JSON.parse(data)
    GoldDedupeService.dedupe(data)
  end
end
