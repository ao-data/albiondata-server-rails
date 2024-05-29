class MarketOrderDedupeService

  include Location

  def initialize(data, server_id, opts)
    @data = data
    @server_id = server_id
    @opts = opts
  end

  def process
    nats = NatsService.new(@server_id)
    nats.send('marketorders.ingest', @data.to_json)

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
    @data['Orders'].each do |order|
      begin
        sha256 = Digest::SHA256.hexdigest(order.to_s)
        if REDIS[@server_id].get("RECORD_SHA256:#{sha256}").nil?
          REDIS[@server_id].set("RECORD_SHA256:#{sha256}", '1', ex: 600)

          next if order['LocationId'] == 0 || !order['LocationId'].is_a?(Numeric)  # sometimes the client sends us 0 for the numeric location id, or a string, we trash this data

          # Hack since albion seems to be multiplying every price by 10000
          order['UnitPriceSilver'] /= 10000

          # merge portals to parent city
          order['LocationId'] = PORTAL_TO_CITY[order['LocationId']] if PORTAL_TO_CITY.has_key?(order['LocationId'])

          redis_deduped << order
        else
          redis_duplicates += 1
        end
      end
    end

    log = { class: 'MarketOrderDedupeService', method: 'dedupe', opts: @opts, redis_duplicates: redis_duplicates }
    Sidekiq.logger.info(log.to_json)

    redis_deduped
  end
end
