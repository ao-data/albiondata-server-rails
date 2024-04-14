class MarketHistoryDedupeService
  def self.dedupe(data)
    json_data = data.to_json
    sha256 = Digest::SHA256.hexdigest(json_data)

    if REDIS.get("HISTORY_RECORD_SHA256:#{sha256}").nil?
      REDIS.set("HISTORY_RECORD_SHA256:#{sha256}", '1', ex: 600)
      return if data['AlbionId'] == 0 # sometimes the client sends us 0 for the numeric item id, we trash this data

      item_id = REDIS.hget('ITEM_IDS', data['AlbionId'])
      raise StandardError.new('MarketHistoryProcessorService: Item ID not found in redis.') if item_id.nil?

      data['AlbionIdString'] = item_id
      json_data = data.to_json

      NatsService.send('markethistories.deduped', json_data)
      MarketHistoryProcessorWorker.perform_async(json_data)
    end
  end
end
