class ActiveSupportNotificationService
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

  def self.write_data(measurement, tags, fields, time = Time.now)
    client = InfluxDB2::Client.new(
      ENV['INFLUXDB_URL'],
      token: ENV['INFLUXDB_TOKEN'],
      bucket: ENV['INFLUXDB_BUCKET'],
      org: ENV['INFLUXDB_ORG'],
      use_ssl: ENV['INFLUXDB_USESSL'],
      precision: InfluxDB2::WritePrecision::NANOSECOND
    )

    write_api = client.create_write_api
    point = InfluxDB2::Point.new(name: measurement)
    tags.each { |key, value| point.add_tag(key, value) }
    fields.each { |key, value| point.add_field(key, value) }
    point.time(time, InfluxDB2::WritePrecision::NANOSECOND)
    write_api.write(data: point)
  end

  def self.market_order_dedupe_service(payload)
    # {"server_id"=>"west", "locations"=>{"1002"=>{"duplicates"=>0, "non_duplicates"=>49}}}

    measurement = 'market_orders'
    payload['locations'].each do |location_id, location_data|
      tags = { server_id: payload['server_id'], location_id: location_id }
      fields = { duplicates: location_data['duplicates'], non_duplicates: location_data['non_duplicates'] }
      write_data(measurement, tags, fields)
    end
  end

  def self.market_history_dedupe_service(payload)
    # {"server_id"=>"west", "locations"=>{"7"=>{"duplicates"=>0, "non_duplicates"=>25}}}

    measurement = 'market_history'
    payload['locations'].each do |location_id, location_data|
      tags = { server_id: payload['server_id'], location_id: location_id }
      fields = { duplicates: location_data['duplicates'], non_duplicates: location_data['non_duplicates'] }
      write_data(measurement, tags, fields)
    end
  end

  def self.gold_dedupe_service(payload)
    # { server_id: server_id, duplicate: false }

    measurement = 'gold_market'
    tags = { server_id: payload['server_id'] }
    fields = { duplicate: payload['duplicate'], non_duplicate: payload['non_duplicate'] }
    write_data(measurement, tags, fields)
  end

  def self.pow_request(payload)
    # {"server_id"=>"west", "client_ip"=>"172.21.0.1", "user_agent"=>"..."}
    #
    measurement = 'pow_request'
    tags = { server_id: payload['server_id'], client_ip: payload['client_ip'], user_agent: payload['user_agent'] || 'unknown' }
    fields = { metric: 1  }
    write_data(measurement, tags, fields)
  end

  def self.pow_response(payload)
    # {"server_id"=>"west", "client_ip"=>"172.21.0.1", "user_agent"=>"...", "action"=>"data_accepted" }
    # {"server_id"=>"west", "client_ip"=>"172.21.0.1", "user_agent"=>"...", "action"=>"pow_not_requested" }
    # {"server_id"=>"west", "client_ip"=>"172.21.0.1", "user_agent"=>"...", "action"=>"invalid_topic" }
    # {"server_id"=>"west", "client_ip"=>"172.21.0.1", "user_agent"=>"...", "action"=>"pow_solved_incorrectly" }
    # {"server_id"=>"west", "client_ip"=>"172.21.0.1", "user_agent"=>"...", "action"=>"invalid_payload" }
    # {"server_id"=>"west", "client_ip"=>"172.21.0.1", "user_agent"=>"...", "action"=>"invalid_json" }
    # {"server_id"=>"west", "client_ip"=>"172.21.0.1", "user_agent"=>"...", "action"=>"data_too_large" }
    # {"server_id"=>"west", "client_ip"=>"172.21.0.1", "user_agent"=>"...", "action"=>"bad_ip" }

    measurement = 'pow_response'
    tags = { server_id: payload['server_id'], action: payload['action'], client_ip: payload['client_ip'], user_agent: payload['user_agent'] || 'unknown' }
    fields = { metric: 1 }
    write_data(measurement, tags, fields)
  end
end