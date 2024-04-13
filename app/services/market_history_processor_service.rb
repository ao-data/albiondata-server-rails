class MarketHistoryProcessorService
  def self.process(data)
    # data = {
    #   "AlbionId": 944,
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

    return if data['AlbionId'] == 0 # sometimes the client sends us 0 for the numeric item id, we trash this data
    item_id = REDIS.hget('ITEM_IDS', data['AlbionId'])
    raise StandardError.new('MarketHistoryProcessorService: Item ID not found in redis.') if item_id.nil?

    new_record_count = 0
    updated_record_count = 0
    new_records = []
    timescale = data['Timescale'] == 0 ? 1 : 6
    data['MarketHistories'].each do |history|
      timestamp = ticks_to_epoch(history['Timestamp'])
      r = MarketHistory.find_by(item_id: item_id, quality: data['QualityLevel'], location: data['LocationId'], timestamp: timestamp, aggregation: timescale)
      if r != nil
        r.item_amount = history['ItemAmount'] if r.item_amount != history['ItemAmount']
        r.silver_amount = history['SilverAmount'] / 10000 if r.silver_amount != history['SilverAmount'] / 10000

        if r.changed?
          r.save
          updated_record_count += 1
        end
      else
        new_records << {
          item_id: item_id,
          quality: data['QualityLevel'],
          location: data['LocationId'],
          timestamp: timestamp,
          aggregation: timescale,
          item_amount: history['ItemAmount'],
          silver_amount: history['SilverAmount'] / 10000
        }
        new_record_count += 1
      end
    end

    MarketHistory.insert_all(new_records) if new_records.length > 0

    puts "\nMarketHistoryProcessorService: New records: #{new_record_count}, Updated records: #{updated_record_count}\n\n"
  end

  def self.ticks_to_epoch(ticks)
    # python example for ticks to epoch
    # In [53]: import datetime
    # In [54]: ticks = 634942626000000000
    # In [55]: start = datetime.datetime(1, 1, 1)
    # In [56]: delta = datetime.timedelta(seconds=ticks/10000000)
    # In [57]: the_actual_date = start + delta
    # In [58]: the_actual_date.timestamp()
    #
    # Ruby example for ticks to epoch
    #
    # ticks = 638483904000000000
    # start = DateTime.parse("0000-01-01T00:00:00Z").to_i
    # delta = start + (ticks/10000000)
    # pp Time.at(delta)
    #
    # shortened version
    Time.at(-62167392000 + (ticks/10000000))
  end
end
