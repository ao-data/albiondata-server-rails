require 'nats/client'

class NatsService


  def listen
    server = 'nats://public:thenewalbiondata@nats.albion-online-data.com:4222'

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

    # nats.subscribe('marketorders.deduped') do |msg|
    #   puts JSON.parse(msg.data)
    #   # puts ''
    #   # puts ''
    #   # BulkMarketOrderUpdate.perform_async(data)
    #   # process_market_data(data)
    # end

    nats.subscribe('marketorders.deduped.bulk') do |msg|
      # puts JSON.parse(msg.data)
      # puts '---------'
      # puts ''
      # puts ''
      # BulkMarketOrderUpdate.perform_async(data)
      # process_market_data(data)
    end

    nats.subscribe('marketorders.ingest') do |msg|
      MarketOrderDedupeWorker.perform_async(msg.data)
    end

    nats.subscribe('goldprices.ingest') do |msg|
      GoldDedupeWorker.perform_async(msg.data)
    end

    while true
      sleep 0.5
    end
    # nats.subscribe('markethistories.ingest') do |data|
    #   puts data
    #   puts ''
    #   puts ''
    #   # process_market_data_deduped(data)
    # end

    # NATS.subscribe('markethistories.deduped') do |data|
    #   puts data
    #   # process_market_data_deduped(data)
    # end

    # NATS.subscribe('msg.*') do |data|
    #   process_market_data_deduped(data)
    # end

    # NATS.subscribe('marketorders.deduped') do |data|
    #   process_market_data_deduped(data)
    # end
  end
end