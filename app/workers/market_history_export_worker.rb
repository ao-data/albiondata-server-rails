class MarketHistoryExportWorker
  include Sidekiq::Worker

  def perform (server_id, year = nil, month = nil)
    MarketHistoryExportService.export(server_id, year, month)
  end
end