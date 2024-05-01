class MarketHistoryProcessorService
  def self.process(data)
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

    new_record_count = 0
    updated_record_count = 0
    new_records = []
    timescale = data['Timescale'] == 0 ? 1 : 6
    data['MarketHistories'].each do |history|
      sha256 = Digest::SHA256.hexdigest(history.to_json)
      next unless REDIS.get("RECORD_HISTORY_SHA256_24H:#{sha256}").nil?

      timestamp = ticks_to_time(history['Timestamp'])
      r = MarketHistory.find_by(item_id: data['AlbionIdString'], quality: data['QualityLevel'], location: data['LocationId'], timestamp: timestamp, aggregation: timescale)
      if r != nil
        r.item_amount = history['ItemAmount'] if r.item_amount != history['ItemAmount']
        r.silver_amount = history['SilverAmount'] if r.silver_amount != history['SilverAmount']

        if r.changed?
          r.save
          updated_record_count += 1
        end
      else
        new_records << {
          item_id: data['AlbionIdString'],
          quality: data['QualityLevel'],
          location: data['LocationId'],
          timestamp: timestamp,
          aggregation: timescale,
          item_amount: history['ItemAmount'],
          silver_amount: history['SilverAmount'] / 10000
        }
        new_record_count += 1
      end

      REDIS.set("RECORD_HISTORY_SHA256_24H:#{sha256}", 1, ex: 86400)
    end

    MarketHistory.insert_all(new_records) if new_records.length > 0

    puts "\nMarketHistoryProcessorService: New records: #{new_record_count}, Updated records: #{updated_record_count}\n\n"
  end

  def self.ticks_to_time(ticks)
    Time.at((ticks - 621355968000000000)/10000000)
  end
end
