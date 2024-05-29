class GoldProcessorWorker
  include Sidekiq::Job

  def perform(data, server_id, opts)
    data = JSON.parse(data)
    opts = JSON.parse(opts)

    GoldProcessorService.new.process(data, server_id, opts)
  end
end