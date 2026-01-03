class BanditEventService
  def process(data, server_id, opts)
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
