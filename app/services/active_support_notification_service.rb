class ActiveSupportNotificationService
  @@client = nil
  @@write_api = nil
  @@mutex = Mutex.new
  @@batch = []
  @@batch_mutex = Mutex.new
  FLUSH_RETRIES = 2

  def self.batch_size
    (ENV['INFLUXDB_BATCH_SIZE'] || '100').to_i
  end

  def self.process(name, payload)
    return unless ENV['METRICS_ENABLED'] == 'true'

    case name
    when 'metrics.market_order_dedupe_service'
      market_order_dedupe_service(payload)
    when 'metrics.market_history_dedupe_service'
      market_history_dedupe_service(payload)
    when 'metrics.gold_dedupe_service'
      gold_dedupe_service(payload)
    when 'metrics.pow_request'
      pow_request(payload)
    when 'metrics.pow_response'
      pow_response(payload)
    else
      Rails.logger.warn "ActiveSupportNotificationService: Unhandled event: #{name}"
    end
  end

  def self.client
    return @@client if @@client

    @@mutex.synchronize do
      return @@client if @@client

      @@client = InfluxDB2::Client.new(
        ENV['INFLUXDB_URL'],
        ENV['INFLUXDB_TOKEN'],
        bucket: ENV['INFLUXDB_BUCKET'],
        org: ENV['INFLUXDB_ORG'],
        use_ssl: false,
        precision: InfluxDB2::WritePrecision::NANOSECOND
      )
      @@write_api = @@client.create_write_api
    end

    @@client
  end

  def self.write_data(measurement, tags, fields, time = Time.now)
    return unless ENV['METRICS_ENABLED'] == 'true'

    point = InfluxDB2::Point.new(name: measurement)
    tags.each { |key, value| point.add_tag(key.to_s, value.to_s) }
    fields.each { |key, value| point.add_field(key.to_s, value) }
    point.time(time, InfluxDB2::WritePrecision::NANOSECOND)

    to_flush = nil
    @@batch_mutex.synchronize do
      @@batch << point
      if @@batch.size >= batch_size
        to_flush = @@batch.dup
        @@batch.clear
      end
    end
    flush_batch_data(to_flush) if to_flush
  end

  def self.flush_batch
    to_write = nil
    @@batch_mutex.synchronize do
      return if @@batch.empty?

      to_write = @@batch.dup
      @@batch.clear
    end
    flush_batch_data(to_write)
  end

  def self.flush_batch_data(to_write)
    return if to_write.nil? || to_write.empty?

    FLUSH_RETRIES.times do |attempt|
      begin
        client
        @@write_api.write(data: to_write)
        return
      rescue => e
        Rails.logger.error("Failed to write metrics batch: #{e.message}#{attempt < FLUSH_RETRIES - 1 ? ' (retrying)' : ''}")
        sleep(0.5 * (attempt + 1)) if attempt < FLUSH_RETRIES - 1
      end
    end
  end

  def self.market_order_dedupe_service(payload)
    measurement = 'market_orders'
    optional_fields = %w[invalid_location_count filtered_orders price_min price_max price_avg offer_count request_count]

    payload['locations'].each do |location_id, location_data|
      tags = { server_id: payload['server_id'], location_id: location_id }
      fields = {
        duplicates: location_data['duplicates'],
        non_duplicates: location_data['non_duplicates']
      }
      optional_fields.each do |key|
        fields[key] = payload[key] if payload.key?(key)
      end
      write_data(measurement, tags, fields)
    end
  end

  def self.market_history_dedupe_service(payload)
    measurement = 'market_history'
    optional_fields = %w[missing_item_id_count invalid_timescale_count]
    locations = payload['locations'] || {}

    if locations.empty? && optional_fields.any? { |k| payload.key?(k) }
      tags = { server_id: payload['server_id'], location_id: '_batch' }
      fields = optional_fields.each_with_object({}) { |k, h| h[k] = payload[k] if payload.key?(k) }
      write_data(measurement, tags, fields) if fields.any?
    end

    locations.each do |location_id, location_data|
      tags = { server_id: payload['server_id'], location_id: location_id }
      fields = {
        duplicates: location_data['duplicates'],
        non_duplicates: location_data['non_duplicates']
      }
      optional_fields.each do |key|
        fields[key] = payload[key] if payload.key?(key)
      end
      write_data(measurement, tags, fields)
    end
  end

  def self.gold_dedupe_service(payload)
    measurement = 'gold_market'
    tags = { server_id: payload['server_id'] }
    fields = { duplicate: payload['duplicate'], non_duplicate: payload['non_duplicate'] }
    write_data(measurement, tags, fields)
  end

  def self.pow_request(payload)
    measurement = 'pow_request'
    tags = { server_id: payload['server_id'], client_ip: payload['client_ip'], user_agent: payload['user_agent'] || 'unknown' }
    fields = { metric: 1 }
    write_data(measurement, tags, fields)
  end

  def self.pow_response(payload)
    measurement = 'pow_response'
    tags = { server_id: payload['server_id'], action: payload['action'], client_ip: payload['client_ip'], user_agent: payload['user_agent'] || 'unknown' }
    fields = { metric: 1 }
    %w[payload_size_bytes order_count history_count].each do |key|
      fields[key] = payload[key] if payload.key?(key)
    end
    write_data(measurement, tags, fields)
  end
end
