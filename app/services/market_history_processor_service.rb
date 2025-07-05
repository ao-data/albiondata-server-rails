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

      return if data['MarketHistories'].blank?

      record_data = data['MarketHistories'].map do |history|
        {
          item_id: data['AlbionIdString'],
          quality: data['QualityLevel'],
          location: data['LocationId'],
          timestamp: ticks_to_time(history['Timestamp']),
          aggregation: data['Timescale'] == 0 ? 1 : 6,
          item_amount: history['ItemAmount'],
          silver_amount: history['SilverAmount']
        }
      end

      min_record, max_record = record_data.minmax_by { |r| r[:timestamp] }
      first_timestamp = min_record[:timestamp]
      last_timestamp = max_record[:timestamp]
      timescale = data['Timescale']

      # Validate timeframe
      duration_in_days = (last_timestamp - first_timestamp) / 1.day
      expected_duration = timescale == 0 ? 1 : 28 # 1 day for hourly, 28 days for 6h

      # Allow for a small tolerance
      # Sidekiq.logger.info("MarketHistoryProcessorService: Checking timeframe for item #{data['AlbionIdString']} at location #{data['LocationId']}. Timescale: #{timescale}. Min: #{first_timestamp}, Max: #{last_timestamp}, Found: #{duration_in_days.round(2)} days, Expected: #{expected_duration} days.")
      if duration_in_days > expected_duration * 1.1
        warn_message = "Unexpected timeframe for item #{data['AlbionIdString']} at location #{data['LocationId']}. Timescale: #{timescale}. Min: #{first_timestamp}, Max: #{last_timestamp}, Found: #{duration_in_days.round(2)} days, Expected: #{expected_duration} days."
        Sidekiq.logger.warn("MarketHistoryProcessorService: #{warn_message}")
        IdentifierService.add_identifier_event(opts, server_id, warn_message)
        return
      end

      # logs
      log = { class: 'MarketHistoryProcessorService', method: 'process',
              server_id: server_id, opts: opts, record_data: record_data }
      Sidekiq.logger.info(log.to_json)
      IdentifierService.add_identifier_event(opts, server_id, "Received on MarketHistoryProcessorService")

      MarketHistory.transaction do
      # Erase all data for the item in the timeframe
        MarketHistory.where(
          item_id: data['AlbionIdString'],
          quality: data['QualityLevel'],
          location: data['LocationId'],
          aggregation: data['Timescale'] == 0 ? 1 : 6,
          timestamp: first_timestamp..last_timestamp
        ).delete_all

        # Insert the new data
        MarketHistory.insert_all(record_data)
      end

      IdentifierService.add_identifier_event(opts, server_id, "Saved to database from MarketHistoryProcessorService")
    end
  end

  def ticks_to_time(ticks)
    Time.at((ticks - 621355968000000000)/10000000)
  end
end
