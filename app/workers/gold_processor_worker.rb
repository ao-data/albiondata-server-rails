class GoldProcessorWorker
  include Sidekiq::Job

  def perform(data)
    data = JSON.parse(data)
    GoldProcessorService.process(data)
  end
end