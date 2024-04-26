class MarketHistoryDedupeService
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

  PORTAL_TO_CITY = {
    9 => 7,      # ThetfordPortal to Thetford
    1301 => 1002, # LymhurstPortal to Lymhurst
    2301 => 2004, # BridgewatchPortal to Bridgewatch
    3301 => 3308, # MartlockPortal to Martlock
    4301 => 4002, # FortSterlingPortal to FortSterling
    3013 => 3005  # Caerleon2 to Caerleon
  }

  def dedupe(data, server_id)
    json_data = data.to_json
    sha256 = Digest::SHA256.hexdigest(json_data)

    if REDIS.get("HISTORY_RECORD_SHA256:#{sha256}").nil?
      REDIS.set("HISTORY_RECORD_SHA256:#{sha256}", '1', ex: 600)
      return if data['AlbionId'] == 0 # sometimes the client sends us 0 for the numeric item id, we trash this data

      item_id = REDIS.hget('ITEM_IDS', data['AlbionId'])
      raise StandardError.new('MarketHistoryProcessorService: Item ID not found in redis.') if item_id.nil?

      data['AlbionIdString'] = item_id
      data['LocationId'] = PORTAL_TO_CITY[data['LocationId']] if PORTAL_TO_CITY.has_key?(data['LocationId'])

      data['MarketHistories'].each do |history|
        history['SilverAmount'] = history['SilverAmount'].to_i / 10000
      end

      json_data = data.to_json

      s = NatsService.new
      s.send('markethistories.deduped', json_data, server_id)
      s.close

      MarketHistoryProcessorWorker.perform_async(json_data, server_id)
    end
  end
end
