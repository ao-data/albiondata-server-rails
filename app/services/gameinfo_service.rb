class GameinfoService
  BASE_URLS = {
    'west' => 'https://gameinfo.albiononline.com',
    'east' => 'https://gameinfo-sgp.albiononline.com',
    'europe' => 'https://gameinfo-ams.albiononline.com'
  }.freeze

  KILL_EVENTS_TOPIC = 'killevents.deduped'
  BATTLES_TOPIC = 'battles.deduped'

  PAGE_SIZE = 51
  # The events feed rejects offsets above 1000.
  EVENTS_MAX_OFFSET = 1000
  EVENTS_PARALLEL_PAGES = ENV.fetch('GAMEINFO_EVENTS_PARALLEL_PAGES', 4).to_i
  BATTLES_MAX_OFFSET = ENV.fetch('GAMEINFO_BATTLES_MAX_OFFSET', 500).to_i

  LOCK_TTL_SECONDS = ENV.fetch('GAMEINFO_LOCK_TTL_SECONDS', 180).to_i
  # Keep LOCK_TTL_SECONDS well above MAX_RUNTIME_SECONDS: a run stops starting requests at the limit, but
  # a request in flight can run past it by HTTP_OPEN_TIMEOUT_SECONDS + HTTP_READ_TIMEOUT_SECONDS or more
  # (the read timeout applies to each read).
  MAX_RUNTIME_SECONDS = ENV.fetch('GAMEINFO_MAX_RUNTIME_SECONDS', 60).to_i
  HTTP_OPEN_TIMEOUT_SECONDS = 10
  HTTP_READ_TIMEOUT_SECONDS = ENV.fetch('GAMEINFO_HTTP_READ_TIMEOUT_SECONDS', 60).to_i
  MAX_ATTEMPTS = 3
  SEEN_TTL_SECONDS = 1.day.to_i

  # A rate limit (429 or Cloudflare 1015), or a request that still fails after its retries, puts that
  # endpoint (events or battles, per server) in a cooldown shared by every run and thread. It doubles
  # with each consecutive one, a Retry-After header can make it longer, and a success resets it.
  RATE_LIMIT_COOLDOWN_BASE_SECONDS = ENV.fetch('GAMEINFO_RATE_LIMIT_COOLDOWN_BASE_SECONDS', 5).to_i
  RATE_LIMIT_COOLDOWN_MAX_SECONDS = ENV.fetch('GAMEINFO_RATE_LIMIT_COOLDOWN_MAX_SECONDS', 60).to_i
  FAILURE_COOLDOWN_BASE_SECONDS = ENV.fetch('GAMEINFO_FAILURE_COOLDOWN_BASE_SECONDS', 30).to_i
  FAILURE_COOLDOWN_MAX_SECONDS = ENV.fetch('GAMEINFO_FAILURE_COOLDOWN_MAX_SECONDS', 300).to_i
  COOLDOWN_LEVEL_TTL_SECONDS = 15.minutes.to_i
  JITTER_MAX_SECONDS = 0.5

  # Battles are only listed once they are over, and never when they have fewer than 3 kills.
  BACKFILL_MIN_KILLS = 3
  BACKFILL_DELAY_SECONDS = 15.minutes.to_i
  BACKFILL_GIVE_UP_SECONDS = 1.hour.to_i
  BACKFILL_BATCH_SIZE = 1000

  # Events older than ~1000 places in the feed are gone, so a stale resume point is dropped.
  EVENTS_RESUME_KEY = 'gameinfo:events:resume_below'
  EVENTS_RESUME_TTL_SECONDS = 30.minutes.to_i

  PENDING_BATTLES_KEY = 'gameinfo:battles:pending'

  RELEASE_LOCK_SCRIPT = "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end"

  def initialize(server_id)
    @server_id = server_id
    @redis = REDIS[server_id]
  end

  # Pages through the feed (newest first) until a page has nothing new. A page with only new events
  # means the run is behind, so the next batches of pages double in size, up to EVENTS_PARALLEL_PAGES
  # fetched at a time.
  #
  # A run that stops early (a failed page or the time limit) leaves unread events below what it
  # published, and the next run would stop at those published pages. So it stores the oldest
  # EventId it reached, and later runs do not stop at a page without new events until they get
  # below it.
  def poll_events
    with_lock('events') do
      published = 0
      offset = 0
      resume_below = @redis.get(EVENTS_RESUME_KEY)&.to_i
      pages_at_once = resume_below ? EVENTS_PARALLEL_PAGES : 1
      caught_up = false
      failed = false
      oldest_event_id = nil
      lag_seconds = nil

      while !caught_up && !failed && offset <= EVENTS_MAX_OFFSET && time_left?
        offsets = (offset..EVENTS_MAX_OFFSET).step(PAGE_SIZE).first(pages_at_once)
        offset = offsets.last + PAGE_SIZE

        get_json_in_parallel(offsets.map { |o| "/api/gameinfo/events?limit=#{PAGE_SIZE}&offset=#{o}" }).each do |events|
          if !events.is_a?(Array)
            failed = true
            next
          elsif events.empty?
            caught_up = true
            next
          end

          event_ids = events.map { |event| event['EventId'] }
          oldest_event_id = [oldest_event_id, *event_ids].compact.min
          lag_seconds ||= seconds_since(events, 'TimeStamp')
          new_events = publish_new(events, KILL_EVENTS_TOPIC) { |event| kill_event_key(event['EventId']) }
          track_battles(new_events)
          published += new_events.size
          caught_up = true if new_events.empty? && (resume_below.nil? || event_ids.max < resume_below)
          pages_at_once = [pages_at_once * 2, EVENTS_PARALLEL_PAGES].min if new_events.size == events.size
        end
      end

      if (caught_up && !failed) || offset > EVENTS_MAX_OFFSET
        @redis.del(EVENTS_RESUME_KEY)
      elsif oldest_event_id
        @redis.set(EVENTS_RESUME_KEY, [resume_below, oldest_event_id].compact.min, ex: EVENTS_RESUME_TTL_SECONDS)
      end

      # missed_older: the scan reached the max offset before catching up, so older events were missed.
      { published: published, lag_seconds: lag_seconds, offset: offset, resume_below: resume_below,
        missed_older: (true if !caught_up && offset > EVENTS_MAX_OFFSET) }
    end
  end

  # Pages through the battles list until a page has nothing new. Battles that show up later
  # deeper in the list are picked up by the backfill.
  def poll_battles
    with_lock('battles') do
      published = 0
      offset = 0
      lag_seconds = nil

      while offset <= BATTLES_MAX_OFFSET && time_left?
        battles = get_json("/api/gameinfo/battles?sort=recent&limit=#{PAGE_SIZE}&offset=#{offset}")
        break unless battles.is_a?(Array) && battles.any?

        lag_seconds ||= seconds_since(battles, 'endTime')
        new_battles = publish_battles(battles)
        published += new_battles
        break if new_battles.zero?

        offset += PAGE_SIZE
      end

      { published: published, backfilled: backfill_battles, lag_seconds: lag_seconds }
    end
  end

  private

  # Fetches battles seen in kill events that the battles list never showed, oldest first and at most
  # BACKFILL_BATCH_SIZE per run.
  def backfill_battles
    published = 0
    now = Time.now.to_i
    pending = @redis.zrangebyscore(PENDING_BATTLES_KEY, '-inf', now - BACKFILL_DELAY_SECONDS,
                                   with_scores: true, limit: [0, BACKFILL_BATCH_SIZE]).to_h
    return 0 if pending.empty?

    battle_ids = pending.keys
    kills = @redis.mget(*battle_ids.map { |battle_id| battle_kills_key(battle_id) })
    seen = @redis.mget(*battle_ids.map { |battle_id| battle_key(battle_id) })
    dropped = battle_ids.zip(kills, seen).filter_map do |battle_id, kill_count, seen_mark|
      battle_id if kill_count.to_i < BACKFILL_MIN_KILLS || seen_mark
    end
    forget_battles(*dropped)

    pending.except(*dropped).each do |battle_id, last_seen_at|
      break if !time_left? || cooling_down?

      battle = get_json("/api/gameinfo/battles/#{battle_id}")
      if battle.is_a?(Hash)
        published += publish_battles([battle])
      elsif last_seen_at < now - BACKFILL_GIVE_UP_SECONDS
        forget_battles(battle_id)
      end
    end

    published
  end

  # Returns how many of the battles were new.
  def publish_battles(battles)
    new_battles = publish_new(battles, BATTLES_TOPIC) { |battle| battle_key(battle['id']) }
    forget_battles(*new_battles.map { |battle| battle['id'] })
    new_battles.size
  end

  # Pending battles are scored by when one of their kills was last seen, so a battle seen late still
  # gets the whole backfill window. Kill counts expire, and battles not seen for BACKFILL_GIVE_UP_SECONDS
  # are trimmed on every write, so the pending battles stay bounded even when the battles job does not run.
  # Battles that were already published are dropped by the backfill before any lookup.
  def track_battles(events)
    kills = events.filter_map { |event| event['BattleId'].presence }.tally
    return if kills.empty?

    now = Time.now.to_i
    @redis.multi do |transaction|
      transaction.zadd(PENDING_BATTLES_KEY, kills.keys.map { |battle_id| [now, battle_id] })
      transaction.zremrangebyscore(PENDING_BATTLES_KEY, '-inf', now - BACKFILL_GIVE_UP_SECONDS)
      kills.each do |battle_id, count|
        transaction.incrby(battle_kills_key(battle_id), count)
        transaction.expire(battle_kills_key(battle_id), BACKFILL_GIVE_UP_SECONDS)
      end
    end
  end

  def forget_battles(*battle_ids)
    return if battle_ids.empty?

    @redis.multi do |transaction|
      transaction.zrem(PENDING_BATTLES_KEY, battle_ids)
      transaction.del(*battle_ids.map { |battle_id| battle_kills_key(battle_id) })
    end
  end

  # Marks the records as published with one pipelined SET NX per record, sends the ones that were not
  # marked before, and returns them. Records that were not sent are unmarked again, including when
  # Sidekiq kills the job on shutdown.
  def publish_new(records, topic, &key)
    keys = records.map(&key)
    marked = @redis.pipelined { |pipeline| keys.each { |k| pipeline.set(k, '1', nx: true, ex: SEEN_TTL_SECONDS) } }
    new_records = records.zip(keys, marked).select(&:last)
    sent = 0
    new_records.each do |record, _key|
      nats.send(topic, record.to_json)
      sent += 1
    end
    new_records.map(&:first)
  ensure
    unsent_keys = new_records.to_a.drop(sent.to_i).map { |_record, k| k }
    @redis.del(*unsent_keys) if unsent_keys.any?
  end

  # Only the HTTP calls run in threads; the results are handled in order on the job's thread.
  def get_json_in_parallel(paths)
    return [get_json(paths.first)] if paths.one?

    paths.map { |path| Thread.new { get_json(path) } }.map(&:value)
  end

  # Returns the parsed body, or nil when the request failed or its endpoint is cooling down. A 404 is
  # not logged, since the backfill gets one for each battle that is not out yet. Server and network
  # errors are retried with a backoff; a rate limit is not retried but starts a cooldown.
  # The random `_` parameter skips the API's response cache, which serves each page URL
  # from a copy up to ~2 minutes old and makes consecutive pages come from different moments.
  def get_json(path)
    return if cooling_down?

    MAX_ATTEMPTS.times do |attempt|
      if attempt > 0
        break unless time_left?
        sleep(2**attempt + jitter)
      end

      response = HTTParty.get("#{BASE_URLS.fetch(@server_id)}#{path}",
                              query: { _: SecureRandom.hex(8) },
                              headers: { 'User-Agent' => 'AlbionDataServer' },
                              open_timeout: HTTP_OPEN_TIMEOUT_SECONDS,
                              read_timeout: HTTP_READ_TIMEOUT_SECONDS)
      if response.success?
        @redis.del(cooldown_level_key)
        return JSON.parse(response.body)
      end
      return if response.code == 404

      log('get_json', path: path, status: response.code)
      if response.code == 429 || response.body.to_s.include?('1015')
        start_cooldown(RATE_LIMIT_COOLDOWN_BASE_SECONDS, RATE_LIMIT_COOLDOWN_MAX_SECONDS, response.headers['retry-after'].to_i)
        return
      end
      return if response.code < 500
    rescue StandardError => e
      log('get_json', path: path, error: e.message)
    end

    start_cooldown(FAILURE_COOLDOWN_BASE_SECONDS, FAILURE_COOLDOWN_MAX_SECONDS)
    nil
  end

  # Cooldowns are per job (the events or battles endpoint) and server.
  def cooling_down?
    @redis.exists?(cooldown_key)
  end

  # retry_after is the Retry-After header in seconds (0 when missing or given as a date).
  def start_cooldown(base_seconds, max_seconds, retry_after = 0)
    level = @redis.multi do |transaction|
      transaction.incr(cooldown_level_key)
      transaction.expire(cooldown_level_key, COOLDOWN_LEVEL_TTL_SECONDS)
    end.first
    seconds = [[base_seconds * 2**(level - 1), max_seconds].min, retry_after].max + jitter
    # Parallel requests can start cooldowns at the same time; never shorten a longer one.
    return if @redis.pttl(cooldown_key) >= seconds * 1000

    @redis.set(cooldown_key, '1', px: (seconds * 1000).round)
    log('get_json', endpoint: @job, cooldown_seconds: seconds.round(1))
    instrument(cooldown_seconds: seconds.round)
  end

  def jitter
    rand * JITTER_MAX_SECONDS
  end

  def cooldown_key
    "gameinfo:cooldown:#{@job}"
  end

  def cooldown_level_key
    "#{cooldown_key}:level"
  end

  # Only one run per job and server at a time. The lock is released when the run finishes
  # successfully, otherwise it expires after LOCK_TTL_SECONDS. The block returns the run's fields,
  # which are logged and sent as metrics (ActiveSupportNotificationService keeps the metric ones).
  def with_lock(job)
    @job = job
    key = "gameinfo:lock:#{job}"
    token = SecureRandom.uuid

    unless @redis.set(key, token, nx: true, ex: LOCK_TTL_SECONDS)
      log("poll_#{job}", message: 'previous run still holds the lock, skipping')
      instrument(skipped: 1)
      return
    end

    @deadline = Time.now + MAX_RUNTIME_SECONDS
    fields = yield.compact.merge(timed_out: time_left? ? 0 : 1)
    log("poll_#{job}", fields)
    instrument(fields)
    @redis.eval(RELEASE_LOCK_SCRIPT, keys: [key], argv: [token])
  ensure
    @nats&.close
    @nats = nil
  end

  def time_left?
    Time.now < @deadline
  end

  def nats
    @nats ||= NatsService.new(@server_id)
  end

  # Sent to InfluxDB by ActiveSupportNotificationService, like the dedupe services' metrics.
  def instrument(fields)
    ActiveSupport::Notifications.instrument('metrics.gameinfo_service', { server_id: @server_id, job: @job }.merge(fields).compact)
  end

  # How far behind the API is: seconds since the newest record's time field. Returns nil when it is
  # missing or malformed, so one bad record does not stop the run.
  def seconds_since(records, field)
    newest = records.filter_map { |record| record[field].presence }.max
    (Time.now - Time.parse(newest)).round if newest
  rescue ArgumentError, TypeError
    nil
  end

  def kill_event_key(event_id)
    "gameinfo:killevent:#{event_id}"
  end

  def battle_key(battle_id)
    "gameinfo:battle:#{battle_id}"
  end

  def battle_kills_key(battle_id)
    "gameinfo:battle:#{battle_id}:kills"
  end

  def log(method, data = {})
    Sidekiq.logger.info({ class: 'GameinfoService', method: method, server_id: @server_id }.merge(data).to_json)
  end
end
