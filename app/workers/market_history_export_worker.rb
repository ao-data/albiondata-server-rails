class MarketHistoryExportWorker
  include Sidekiq::Worker

  def perform (server_id, year = nil, month = nil, delete_data = false)
    MarketHistoryExportService.export(server_id, year, month, delete_data)
  end
end