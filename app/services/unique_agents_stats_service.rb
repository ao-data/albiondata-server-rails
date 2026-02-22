# frozen_string_literal: true

class UniqueAgentsStatsService
  SERVER_LABELS = { "east" => "Asia", "europe" => "Europe", "west" => "Americas" }.freeze

  CACHE_KEY = "unique_agents_stats"
  REFRESH_LOCK_KEY = "unique_agents_stats_refreshing"
  CACHE_EXPIRY = 10.minutes
  STALE_THRESHOLD = 5.minutes
  REFRESH_LOCK_EXPIRY = 2.minutes

  # Returns chart-ready data (from cache or nil). Never blocks on InfluxDB.
  # If cache is older than 5 min, triggers a background refresh to repopulate cache.
  # Format: { labels: [ISO time strings], datasets: [ { server_id: "east", label: "Asia", data: [n, ...] }, ... ] }
  def self.call
    entry = Rails.cache.read(CACHE_KEY)

    if entry.nil?
      spawn_refresh_if_needed
      return nil
    end

    cached_at = entry[:cached_at] || 0
    age = Time.now.to_f - cached_at

    spawn_refresh_if_needed if age >= STALE_THRESHOLD.to_f

    entry[:data]
  end

  def self.spawn_refresh_if_needed
    return if Rails.cache.read(REFRESH_LOCK_KEY)

    Rails.cache.write(REFRESH_LOCK_KEY, true, expires_in: REFRESH_LOCK_EXPIRY)

    Thread.new do
      begin
        data = fetch_data
        if data
          Rails.cache.write(
            CACHE_KEY,
            { data: data, cached_at: Time.now.to_f },
            expires_in: CACHE_EXPIRY
          )
        end
      rescue StandardError => e
        Rails.logger.warn("[UniqueAgentsStatsService] background refresh failed: #{e.message}")
      ensure
        Rails.cache.delete(REFRESH_LOCK_KEY)
      end
    end
  end

  # Fetches from InfluxDB and builds chart data. Can block; used from background thread.
  def self.fetch_data
    return nil if ENV['INFLUXDB_URL'].blank? || ENV['INFLUXDB_TOKEN'].blank?

    bucket = ENV['INFLUXDB_BUCKET'].presence || 'AODP'
    org = ENV['INFLUXDB_ORG']

    flux = <<~FLUX.strip
      from(bucket: "#{bucket}")
        |> range(start: -24h, stop: now())
        |> filter(fn: (r) => r["_measurement"] == "pow_request")
        |> group(columns: ["server_id"])
        |> window(every: 15m)
        |> distinct(column: "client_ip")
        |> count()
        |> duplicate(column: "_start", as: "_time")
        |> window(every: inf)
    FLUX

    client = ActiveSupportNotificationService.client
    query_api = client.create_query_api
    tables = query_api.query(query: flux, org: org)
    build_chart_data(tables)
  rescue StandardError => e
    Rails.logger.warn("[UniqueAgentsStatsService] #{e.message}")
    nil
  end

  def self.build_chart_data(tables)
    points = []
    tables.each do |table|
      next if table.records.empty?

      server_id = table.records.first.values['server_id']&.to_s || 'unknown'
      table.records.each do |rec|
        t = rec.values['_time']
        v = rec.values['_value']
        next if t.nil? || v.nil?

        # InfluxDB returns UTC; keep as UTC through to the frontend
        time = t.is_a?(String) ? Time.zone.parse(t) : t
        time = time.utc if time.respond_to?(:utc)
        points << { time: time, server_id: server_id, value: v.to_i }
      end
    end

    return nil if points.empty?

    labels = points.map { |p| p[:time] }.uniq.sort
    server_ids = points.map { |p| p[:server_id] }.uniq.sort
    value_by = points.group_by { |p| [p[:time], p[:server_id]] }.transform_values { |a| a.first[:value] }

    datasets = server_ids.map do |sid|
      {
        server_id: sid,
        label: SERVER_LABELS[sid] || sid.capitalize,
        data: labels.map { |t| value_by[[t, sid]] || 0 }
      }
    end

    {
      labels: labels.map { |t| t.respond_to?(:utc) ? t.utc.iso8601(3) : (t.respond_to?(:iso8601) ? t.iso8601(3) : t.to_s) },
      datasets: datasets
    }
  end
end
