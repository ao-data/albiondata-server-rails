class MarketHistoryExportWorker
  include Sidekiq::Worker

  def perform (server_id, year = nil, month = nil, delete_data = false)
    MarketHistoryExportService.export(server_id, year, month)

    if delete_data
      Multidb.use(server_id.to_sym) do
        MarketHistory.where("timestamp between ? and ?", Time.new(year, month, 1), Time.new(year, month, 1).end_of_month).delete_all
      end
    end
  end
end