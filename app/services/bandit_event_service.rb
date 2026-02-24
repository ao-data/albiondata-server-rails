class BanditEventService
  BANDIT_EVENT_MIN_DISTINCT_IPS = ENV.fetch('BANDIT_EVENT_MIN_DISTINCT_IPS', 5).to_i
  BANDIT_EVENT_IP_TTL_SECONDS = ENV.fetch('BANDIT_EVENT_IP_TTL_SECONDS', 600).to_i
  CSHARP_TICKS_UNIX_EPOCH = 621355968000000000
  CSHARP_TICKS_PER_SECOND = 10_000_000

  def process(data, server_id, opts)
    log = { class: 'BanditEventService', method: 'process', data: data, server_id: server_id, opts: opts }
    Sidekiq.logger.info(log.to_json)

    client_ip = opts.is_a?(Hash) ? (opts['client_ip'] || opts[:client_ip]) : nil
    event_time = data.key?('EventTime') ? data['EventTime'] : data[:EventTime]
    phase = data.key?('Phase') ? data['Phase'] : data[:Phase]

    if client_ip.nil? || event_time.nil? || phase.nil?
      IdentifierService.add_identifier_event(opts, server_id, 'Received on BanditEventService, missing event fields or client ip, ignored')
      return
    end

    parsed_event_time = parse_event_time_ticks(event_time)
    unless parsed_event_time
      IdentifierService.add_identifier_event(opts, server_id, 'Received on BanditEventService, invalid EventTime ticks, ignored')
      return
    end

    now = Time.now.utc
    if parsed_event_time < now || parsed_event_time > (now + 5.hours)
      IdentifierService.add_identifier_event(opts, server_id, 'Received on BanditEventService, EventTime out of allowed window, ignored')
      return
    end

    key = "event:#{event_time}:#{phase}:ips"
    redis = REDIS[server_id]
    redis.sadd(key, client_ip)
    redis.expire(key, BANDIT_EVENT_IP_TTL_SECONDS)
    distinct_ips = redis.scard(key)

    if distinct_ips > BANDIT_EVENT_MIN_DISTINCT_IPS
      json_data = data.to_json
      nats = NatsService.new(server_id)
      nats.send('banditevent.ingest', json_data)
      nats.close
      IdentifierService.add_identifier_event(opts, server_id, "Received on BanditEventService, distinct ips #{distinct_ips}, sent to NATS")
    else
      IdentifierService.add_identifier_event(opts, server_id, "Received on BanditEventService, distinct ips #{distinct_ips}, below threshold")
    end
  end

  private

  def parse_event_time_ticks(ticks)
    ticks_i = Integer(ticks)
    return nil if ticks_i < CSHARP_TICKS_UNIX_EPOCH

    seconds = (ticks_i - CSHARP_TICKS_UNIX_EPOCH) / CSHARP_TICKS_PER_SECOND.to_f
    Time.at(seconds).utc
  rescue ArgumentError, TypeError, RangeError
    nil
  end
end
