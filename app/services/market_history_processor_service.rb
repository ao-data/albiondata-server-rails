class MarketHistoryProcessorService
  def process(data, server_id, opts)
    Multidb.use(server_id.to_sym) do

      # data = {
      #   "AlbionId": 944,
      #   "AlbionIdString": "T4_BAG",
      #   "LocationId": 3005,
      #   "QualityLevel": 1,
      #   "Timescale": 0,
      #   "MarketHistories": [
      #     {
      #       "ItemAmount": 24,
      #       "SilverAmount": 960000,
      #       "Timestamp": 638464104000000000
      #     }
      #   ]
      # }

      record_data = []
      data['MarketHistories'].each do |history|
        record_data << {
          item_id: data['AlbionIdString'],
          quality: data['QualityLevel'],
          location: data['LocationId'],
          timestamp: ticks_to_time(history['Timestamp']),
          aggregation: data['Timescale'] == 0 ? 1 : 6,
          item_amount: history['ItemAmount'],
          silver_amount: history['SilverAmount']
        }
      end

      # logs
      log = { class: 'MarketHistoryProcessorService', method: 'process',
              server_id: server_id, opts: opts, record_data: record_data }
      Sidekiq.logger.info(log.to_json)

      MarketHistory.upsert_all(record_data, update_only: [:item_amount, :silver_amount])
    end
  end

  def ticks_to_time(ticks)
    Time.at((ticks - 621355968000000000)/10000000)
  end
end
