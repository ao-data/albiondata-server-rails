class FestivitiesService
  DEDUPED_TOPIC = 'festivities.deduped'
  CURRENT_SNAPSHOT_KEY = 'festivities:current'
  CURRENT_DIGEST_KEY = 'festivities:current:digest'

  MIN_DISTINCT_IPS = ENV.fetch('FESTIVITIES_MIN_DISTINCT_IPS', 5).to_i
  VOTE_TTL_SECONDS = ENV.fetch('FESTIVITIES_VOTE_TTL_SECONDS', 600).to_i
  PUBLISH_LOCK_TTL_SECONDS = ENV.fetch('FESTIVITIES_PUBLISH_LOCK_TTL_SECONDS', 60).to_i

  MAX_EVENTS = 256
  MAX_CATEGORY_LENGTH = 64
  MAX_UNIQUE_NAME_LENGTH = 128
  MAX_TIME_DISTANCE = 2.years
  CSHARP_TICKS_UNIX_EPOCH = 621355968000000000
  CSHARP_TICKS_PER_SECOND = 10_000_000

  def process(data, server_id, opts)
    log = { class: 'FestivitiesService', method: 'process', data: data, server_id: server_id, opts: opts }
    Sidekiq.logger.info(log.to_json)

    client_ip = opts.is_a?(Hash) ? (opts['client_ip'] || opts[:client_ip]) : nil
    now = Time.now.utc
    events = normalize_events(data, now)

    if client_ip.blank? || events.nil?
      IdentifierService.add_identifier_event(opts, server_id, 'Received on FestivitiesService, invalid payload or missing client ip, ignored')
      return
    end

    payload = { 'Events' => events }
    payload_json = payload.to_json
    digest = Digest::SHA256.hexdigest(payload_json)
    redis = REDIS[server_id]
    distinct_ips = register_vote(redis, digest, client_ip, now)

    if distinct_ips < MIN_DISTINCT_IPS
      IdentifierService.add_identifier_event(opts, server_id, "Received on FestivitiesService, distinct ips #{distinct_ips}, below threshold")
      return
    end

    expires_at = snapshot_expiry(events)
    expires_in = (expires_at - now).ceil
    snapshot = payload.merge(
      'Server' => server_id,
      'ConfirmedAt' => now.iso8601,
      'ExpiresAt' => expires_at.iso8601
    )

    if redis.get(CURRENT_DIGEST_KEY) == digest
      store_snapshot(redis, snapshot, digest, expires_in)
      IdentifierService.add_identifier_event(opts, server_id, "Received on FestivitiesService, distinct ips #{distinct_ips}, current snapshot refreshed")
      return
    end

    publish_lock_key = "festivities:publish:#{digest}"
    unless redis.set(publish_lock_key, '1', nx: true, ex: PUBLISH_LOCK_TTL_SECONDS)
      IdentifierService.add_identifier_event(opts, server_id, 'Received on FestivitiesService, snapshot publication already in progress')
      return
    end

    publish_snapshot(redis, payload_json, snapshot, digest, expires_in, publish_lock_key)
    IdentifierService.add_identifier_event(opts, server_id, "Received on FestivitiesService, distinct ips #{distinct_ips}, sent to NATS")
  end

  private

  def normalize_events(data, now)
    events = data.is_a?(Hash) ? (data['Events'] || data[:Events]) : nil
    return nil unless events.is_a?(Array) && events.any? && events.length <= MAX_EVENTS

    normalized = events.map do |event|
      normalize_event(event, now)
    end
    return nil if normalized.any?(&:nil?)
    return nil unless normalized.any? { |event| event_active?(event, now) }

    normalized.sort_by! do |event|
      [event['Kind'], event['Category'], event['UniqueName'], event['StartTime'], event['EndTime']]
    end
    return nil unless normalized.uniq.length == normalized.length

    normalized
  end

  def normalize_event(event, now)
    return nil unless event.is_a?(Hash)

    kind = event['Kind'] || event[:Kind]
    category = event.key?('Category') ? event['Category'] : event[:Category]
    unique_name = event['UniqueName'] || event[:UniqueName]
    start_time = event['StartTime'] || event[:StartTime]
    end_time = event['EndTime'] || event[:EndTime]

    return nil unless kind.is_a?(Integer) && kind.between?(0, 255)
    return nil unless valid_category?(category)
    return nil unless valid_unique_name?(unique_name)
    return nil unless start_time.is_a?(Integer) && end_time.is_a?(Integer)
    return nil if start_time < CSHARP_TICKS_UNIX_EPOCH || end_time <= start_time

    starts_at = ticks_to_time(start_time)
    ends_at = ticks_to_time(end_time)
    return nil if ends_at <= now
    return nil if starts_at < now - MAX_TIME_DISTANCE || ends_at > now + MAX_TIME_DISTANCE

    {
      'Kind' => kind,
      'Category' => category,
      'UniqueName' => unique_name,
      'StartTime' => start_time,
      'EndTime' => end_time
    }
  rescue ArgumentError, RangeError
    nil
  end

  def valid_category?(category)
    category.is_a?(String) && category.length <= MAX_CATEGORY_LENGTH && category.match?(/\A[A-Z0-9_]*\z/)
  end

  def valid_unique_name?(unique_name)
    unique_name.is_a?(String) && unique_name.length.between?(1, MAX_UNIQUE_NAME_LENGTH) && unique_name.match?(/\A[A-Z0-9_]+\z/)
  end

  def ticks_to_time(ticks)
    seconds = (ticks - CSHARP_TICKS_UNIX_EPOCH) / CSHARP_TICKS_PER_SECOND.to_f
    Time.at(seconds).utc
  end

  def event_active?(event, now)
    ticks_to_time(event['StartTime']) <= now && ticks_to_time(event['EndTime']) >= now
  end

  def snapshot_expiry(events)
    events.map { |event| ticks_to_time(event['EndTime']) }.min
  end

  def register_vote(redis, digest, client_ip, now)
    voter_id = Digest::SHA256.hexdigest(client_ip)
    voter_key = "festivities:voter:#{voter_id}"
    current_candidate_key = candidate_key(digest)
    previous_digest = redis.get(voter_key)

    if previous_digest.present? && previous_digest != digest
      redis.zrem(candidate_key(previous_digest), voter_id)
    end

    redis.multi do |transaction|
      transaction.set(voter_key, digest, ex: VOTE_TTL_SECONDS)
      transaction.zadd(current_candidate_key, now.to_i, voter_id)
      transaction.zremrangebyscore(current_candidate_key, '-inf', now.to_i - VOTE_TTL_SECONDS)
      transaction.expire(current_candidate_key, VOTE_TTL_SECONDS)
    end

    redis.zcard(current_candidate_key)
  end

  def candidate_key(digest)
    "festivities:candidate:#{digest}:voters"
  end

  def publish_snapshot(redis, payload_json, snapshot, digest, expires_in, publish_lock_key)
    nats = NatsService.new(snapshot['Server'])
    nats.send(DEDUPED_TOPIC, payload_json)

    store_snapshot(redis, snapshot, digest, expires_in, publish_lock_key)
  rescue StandardError
    redis.del(publish_lock_key)
    raise
  ensure
    nats&.close
  end

  def store_snapshot(redis, snapshot, digest, expires_in, publish_lock_key = nil)
    redis.multi do |transaction|
      transaction.set(CURRENT_SNAPSHOT_KEY, snapshot.to_json, ex: expires_in)
      transaction.set(CURRENT_DIGEST_KEY, digest, ex: expires_in)
      transaction.del(publish_lock_key) if publish_lock_key
    end
  end
end
