class GoldProcessorWorker
  include Sidekiq::Job

  def perform(data, server_id)
    data = JSON.parse(data)
    GoldProcessorService.new.process(data, server_id)
  end
end