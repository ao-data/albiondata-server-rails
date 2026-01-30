class BanditEventService
  def process(data, server_id, opts)
    # Validations
    # Expected: { 'EventTime' => 638997538711438026 }
    data = data.slice("EventTime") # We only need a key of EventTime
    data["EventTime"] = data["EventTime"].to_i # EventTime will always be an integer

    return if data["EventTime"] == 0 # Don't forward if data does not match schema

    json_data = data.to_json
    json_opts = opts.to_json

    nats = NatsService.new(server_id)
    nats.send('banditevent.ingest', json_data)
    nats.close

    log = { class: 'BanditEventService', method: 'process', data: data, server_id: server_id, opts: opts }
    Sidekiq.logger.info(log.to_json)
    IdentifierService.add_identifier_event(opts, server_id, 'Received on BanditEventService')

  end
end
