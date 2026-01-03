class BanditEventWorker
  include Sidekiq::Job

  def perform(data, server_id, opts)
    data = JSON.parse(data)
    opts = JSON.parse(opts)

    BanditEventService.new.process(data, server_id, opts)
  end
end
