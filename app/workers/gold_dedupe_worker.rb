class GoldDedupeWorker
  include Sidekiq::Worker

  def perform(data, server_id, opts)
    Multidb.use(server_id) do
      data = JSON.parse(data)
      opts = JSON.parse(opts)
      GoldDedupeService.new.dedupe(data, server_id, opts)
    end
  end
end
