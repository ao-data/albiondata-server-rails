class MarketHistoryMonthlyExporterWorker
  include Sidekiq::Job
  sidekiq_options queue: :low

  def perform
  end
end