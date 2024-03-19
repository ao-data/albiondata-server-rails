class GoldDedupeService
  def self.dedupe(data)
    json_data = data.to_json
    sha256 = Digest::SHA256.hexdigest(json_data)
    if REDIS.get("GOLD_RECORD_SHA256:#{sha256}").nil?
      REDIS.set("GOLD_RECORD_SHA256:#{sha256}", '1', ex: 600)

      # TODO: send data to nats
      GoldProcessorWorker.perform_async(json_data)
    end
  end
end
