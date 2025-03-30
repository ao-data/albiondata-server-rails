class ActiveSupportNotificationWorker
  include Sidekiq::Worker

  def perform(name, payload)
    payload = JSON.parse(payload)
    ActiveSupportNotificationService.process(name, payload)
  end
end
