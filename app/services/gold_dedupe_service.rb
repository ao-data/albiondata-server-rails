class GoldDedupeService
  def dedupe(data, server_id, opts)
    json_data = data.to_json
    json_opts = opts.to_json

    nats = NatsService.new(server_id)
    nats.send('goldprices.ingest', json_data)

    log = { class: 'GoldDedupeService', method: 'dedupe', data: data, server_id: server_id, opts: opts }
    sha256 = Digest::SHA256.hexdigest(json_data)
    if REDIS[server_id].get("GOLD_RECORD_SHA256:#{sha256}").nil?
      REDIS[server_id].set("GOLD_RECORD_SHA256:#{sha256}", '1', ex: 600)

      nats.send('goldprices.deduped', json_data)

      log[:message] = "data not duplicate"
      Sidekiq.logger.info(log.to_json)
      GoldProcessorWorker.perform_async(json_data, server_id, json_opts)
      IdentifierService.add_identifier_event(opts, 'Received on GoldDedupeService, not duplicate, sent to GoldProcessorWorker')
    else
      log[:message] = "data duplicate"
      Sidekiq.logger.info(log.to_json)
      IdentifierService.add_identifier_event(opts, 'Received on GoldDedupeService, data is duplicate, so ignored')
    end

    nats.close
  end
end
