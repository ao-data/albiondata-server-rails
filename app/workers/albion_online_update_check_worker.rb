class AlbionOnlineUpdateCheckWorker
  include Sidekiq::Worker

  def perform
    AlbionOnlineUpdateCheckService.check
  end
end
