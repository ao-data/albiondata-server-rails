class BattlePollWorker
  include Sidekiq::Worker
  # Runs on its own queue and Sidekiq process (RUN_MODE=sidekiq_gameinfo) so slow API calls never
  # hold the threads of the main Sidekiq process. The next scheduled run is the retry.
  sidekiq_options queue: :gameinfo, retry: false

  def perform(server_id)
    GameinfoService.new(server_id).poll_battles
  end
end
