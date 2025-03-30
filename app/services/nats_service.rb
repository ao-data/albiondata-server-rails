require 'nats/client'

class NatsService

  def initialize(server_id)
    @server_id = server_id
    server = case server_id
             when 'west'
               ENV['NATS_WEST_URL']
             when 'east'
               ENV['NATS_EAST_URL']
             when 'europe'
               ENV['NATS_EUROPE_URL']
             else
               ENV['NATS_WEST_URL']
             end
    @nats = NATS.connect(server)
  end

  def close
    @nats.close
    @nats = nil
  end

  def send(topic, data)
    return if ENV['NATS_SEND_DISABLE'] == 'true'
    @nats.publish(topic, data)
  end

  def opts
    @opts ||= { client_ip: '0.0.0.0', user_agent: 'nats_service', identifier: SecureRandom.uuid }.to_json
  end

  def listen
    server = case @server_id
             when 'west'
               ENV['NATS_WEST_URL']
             when 'east'
               ENV['NATS_EAST_URL']
             when 'europe'
               ENV['NATS_EUROPE_URL']
             else
               ENV['NATS_WEST_URL']
             end

    nats = NATS.connect(server)
    puts "Connected to #{nats.connected_server}"

    nats.on_error do |e|
      puts "Error: #{e}"
    end

    nats.on_reconnect do
      puts "Reconnected to server at #{nats.connected_server}"
    end

    nats.on_disconnect do
      puts "Disconnected!"
    end

    nats.on_close do
      puts "Connection to NATS closed"
    end

    nats.subscribe('marketorders.ingest') do |msg|
      puts "Receiving market order data from NATS"
      MarketOrderDedupeWorker.perform_async(msg.data, @server_id, opts)
    end

    nats.subscribe('goldprices.ingest') do |msg|
      puts "Receiving gold price data from NATS"
      GoldDedupeWorker.perform_async(msg.data, @server_id, opts)
    end

    nats.subscribe('markethistories.ingest') do |msg|
      puts "Receiving market history data from NATS"
      MarketHistoryDedupeWorker.perform_async(msg.data, @server_id, opts)
    end

    while true
      sleep 0.5
    end
  end
end
