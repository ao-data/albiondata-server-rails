require 'nats/client'

class NatsService

  def self.send(topic, data, server_id)
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

    nats = NATS.connect(server)
    nats.publish(topic, data)
    nats.close
  end

  def listen(server_id)
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
      MarketOrderDedupeWorker.perform_async(msg.data)
    end

    nats.subscribe('goldprices.ingest') do |msg|
      puts "Receiving gold price data from NATS"
      GoldDedupeWorker.perform_async(msg.data)
    end

    nats.subscribe('markethistories.ingest') do |msg|
      puts "Receiving market history data from NATS"
      MarketHistoryDedupeWorker.perform_async(msg.data)
    end

    while true
      sleep 0.5
    end
  end
end