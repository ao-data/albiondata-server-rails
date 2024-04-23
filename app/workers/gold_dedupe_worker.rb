class GoldDedupeWorker
  include Sidekiq::Worker

  def perform(data, server_id)
    Multidb.use(server_id) do
      data = JSON.parse(data)
      GoldDedupeService.dedupe(data, server_id)
    end
  end
end
