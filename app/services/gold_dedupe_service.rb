class GoldDedupeService
  def dedupe(data, server_id)
    json_data = data.to_json

    nats = NatsService.new(server_id)
    nats.send('goldprices.ingest', json_data)

    sha256 = Digest::SHA256.hexdigest(json_data)
    if REDIS[server_id].get("GOLD_RECORD_SHA256:#{sha256}").nil?
      REDIS[server_id].set("GOLD_RECORD_SHA256:#{sha256}", '1', ex: 600)

      nats.send('goldprices.deduped', json_data)

      GoldProcessorWorker.perform_async(json_data, server_id)
    end

    nats.close
  end
end
