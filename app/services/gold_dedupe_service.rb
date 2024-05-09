class GoldDedupeService
  def dedupe(data, server_id)
    json_data = data.to_json
    sha256 = Digest::SHA256.hexdigest(json_data)
    if REDIS.get("GOLD_RECORD_SHA256:#{sha256}").nil?
      REDIS.set("GOLD_RECORD_SHA256:#{sha256}", '1', ex: 600)

      s = NatsService.new(server_id)
      s.send('marketorders.deduped', json_data)
      s.close

      GoldProcessorWorker.perform_async(json_data, server_id)
    end
  end
end
