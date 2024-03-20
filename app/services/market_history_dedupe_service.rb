class MarketHistoryDedupeService
  def self.dedupe(data)
    json_data = data.to_json
    sha256 = Digest::SHA256.hexdigest(json_data)
    if REDIS.get("HISTORY_RECORD_SHA256:#{sha256}").nil?
      REDIS.set("HISTORY_RECORD_SHA256:#{sha256}", '1', ex: 600)

      # TODO: send data to nats
      MarketHistoryProcessorWorker.perform_async(json_data)

      puts "IS NOT DUPE"
    else
      puts "IS DUPE"
    end
  end
end
