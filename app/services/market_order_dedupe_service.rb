class MarketOrderDedupeService

  include Location

  def initialize(data, server_id, opts)
    @data = data
    @server_id = server_id
    @opts = opts
  end

  def process

    @data['Orders'].each do |order|
      begin
          order['LocationId'] = parse_location_integer(order['LocationId'])
      end
    end

    # Filter out orders with nil LocationId
    @data['Orders'] = @data['Orders'].reject { |order| order['LocationId'].nil? }
    
    # Return early if no valid orders
    if @data['Orders'].empty?
      IdentifierService.add_identifier_event(@opts, @server_id, "Received on MarketOrderDedupeService, no valid orders found")
      return
    end
    
    nats = NatsService.new(@server_id)
    nats.send('marketorders.ingest', @data.to_json)
    IdentifierService.add_identifier_event(@opts, @server_id, "Received on MarketOrderDedupeService, sent to NATS marketorders.ingest")

    deduped_records = dedupe

    if deduped_records.any?

      # send single records to NATS
      deduped_records.each do
        |record| nats.send('marketorders.deduped', record.to_json)
      end

      # Send bulk records to NATS
      nats.send('marketorders.deduped.bulk', deduped_records.to_json)

      # logs
      log = { class: 'MarketOrderDedupeService', method: 'process', data: @data, server_id: @server_id, opts: @opts,
              deduped_recprds: deduped_records }
      Sidekiq.logger.info(log.to_json)

      # Send bulk records to Sidekiq
      MarketOrderProcessorWorker.perform_async(deduped_records.to_json, @server_id, @opts.to_json)
      IdentifierService.add_identifier_event(@opts, @server_id, "From MarketOrderDedupeService, non duplicate prices found, sent to NATS marketorders.deduped, marketorders.deduped.bulk, passed on to MarketOrderProcessorWorker")
    end

    nats.close
  end

  def dedupe
    # @orders = [{"Id"=>12226808117,
    #  "ItemTypeId"=>"T1_MEAL_SEAWEEDSALAD",
    #  "ItemGroupTypeId"=>"T1_MEAL_SEAWEEDSALAD",
    #  "LocationId"=>1002,
    #  "QualityLevel"=>1,
    #  "EnchantmentLevel"=>0,
    #  "UnitPriceSilver"=>2490000,
    #  "Amount"=>15,
    #  "AuctionType"=>"offer",
    #  "Expires"=>"2024-04-15T00:24:27.605927"}]

    # remove duplicates found in redis, 10 minute based for NATS subscribers
    redis_duplicates = 0
    redis_deduped = []
    metrics = { server_id: @server_id, locations: {}}
    @data['Orders'].each do |order|
      begin
        sha256 = Digest::SHA256.hexdigest(order.to_s)
        if REDIS[@server_id].get("RECORD_SHA256:#{sha256}").nil?
          REDIS[@server_id].set("RECORD_SHA256:#{sha256}", '1', ex: 600)

          # Hack since albion seems to be multiplying every price by 10000
          order['UnitPriceSilver'] /= 10000

          # merge portals to parent city
          order['LocationId'] = PORTAL_TO_CITY[order['LocationId']] if PORTAL_TO_CITY.has_key?(order['LocationId'])

          # add to metrics for location
          metrics[:locations][order['LocationId']] = { duplicates: 0, non_duplicates: 0 } if metrics[:locations][order['LocationId']].nil?
          metrics[:locations][order['LocationId']][:non_duplicates] += 1

          redis_deduped << order
        else
          # add to metrics for location
          metrics[:locations][order['LocationId']] = { duplicates: 0, non_duplicates: 0 } if metrics[:locations][order['LocationId']].nil?
          metrics[:locations][order['LocationId']][:duplicates] += 1

          redis_duplicates += 1
        end
      end
    end

    log = { class: 'MarketOrderDedupeService', method: 'dedupe', opts: @opts, redis_duplicates: redis_duplicates }
    Sidekiq.logger.info(log.to_json)
    IdentifierService.add_identifier_event(@opts, @server_id, "Received on MarketOrderDedupeService dedupe method, uniques found: #{redis_deduped.length}, duplicates found: #{redis_duplicates}")

    ActiveSupport::Notifications.instrument("metrics.market_order_dedupe_service", metrics)

    redis_deduped
  end
end
