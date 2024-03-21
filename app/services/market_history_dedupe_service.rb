class MarketHistoryDedupeService
  def self.dedupe(data)
    json_data = data.to_json
    sha256 = Digest::SHA256.hexdigest(json_data)
    if REDIS.get("HISTORY_RECORD_SHA256:#{sha256}").nil?
      REDIS.set("HISTORY_RECORD_SHA256:#{sha256}", '1', ex: 600)

      NatsService.send('markethistories.deduped', json_data)
      MarketHistoryProcessorWorker.perform_async(json_data)
    end
  end
end
