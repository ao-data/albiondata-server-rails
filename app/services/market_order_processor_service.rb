class MarketOrderProcessorService

  def initialize(orders, server_id)
    @orders = orders
    @new_records = 0
    @redis_duplicates = 0
    @duplicate_records = 0
    @invalid_records = 0
    @updated_records = 0
    @unupdated_records = 0
    @server_id = server_id
    Multidb.use(server_id.to_sym)
  end

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

  def process
    # separate duplicates found in redis and update their updated_at, 24 hour based
    dupe_records, deduped_records = dedupe_24h

    # # update duplicates updated_at
    update_dupe_records(dupe_records)

    # separate new and old records
    new_records, old_records = separate_new_from_old_records(deduped_records)

    # add new records
    add_new_records(new_records)

    # update old records
    update_old_records(old_records)

    puts ''
    puts "MarketOrderProcessorService: New records: #{@new_records}, Duplicate records: #{@duplicate_records}, Updated records: #{@updated_records}, Unupdated records: #{@unupdated_records}, Invalid records: #{@invalid_records}, Redis duplicates: #{@redis_duplicates}"
    puts ''
  end

  def update_dupe_records(dupe_records)
    MarketOrder.where(albion_id: dupe_records.map { |order| order["Id"] }).update_all(updated_at: Time.now)
  end

  def dedupe_24h
    redis_deduped = []
    redis_duped = []

    @orders.each do |order|
      begin
        sha256 = Digest::SHA256.hexdigest(order.to_s)
        if REDIS.get("RECORD_SHA256_24H:#{sha256}").nil?
          REDIS.set("RECORD_SHA256_24H:#{sha256}", 1, ex: 86400)
          redis_deduped << order
        else
          redis_duped << order
          @redis_duplicates += 1
        end
      end
    end

    [redis_duped, redis_deduped]
  end

  def separate_new_from_old_records(deduped_records)
    new_records = []
    old_records = []

    alibon_ids = deduped_records.map { |order| order["Id"] }
    found_albion_ids = MarketOrder.where(albion_id: alibon_ids).pluck(:albion_id)

    deduped_records.each do |order|
      if found_albion_ids.include?(order["Id"])
        old_records << order
      else
        new_records << order
      end
    end

    [new_records, old_records]
  end

  def add_new_records(new_records)
    new_record_data = []
    new_records.each do |order|
      expires = DateTime.parse(order['Expires']).year
      expires = DateTime.now + 1.month if expires.year > 2050 # black market expires "never expire", so we fake it

      new_record_data << {
        albion_id: order["Id"],
        item_id: order["ItemTypeId"],
        quality_level: order["QualityLevel"],
        enchantment_level: order["EnchantmentLevel"],
        price: order["UnitPriceSilver"],
        initial_amount: order["Amount"],
        amount: order["Amount"],
        auction_type: order["AuctionType"],
        expires: expires,
        location: order["LocationId"]
      }
      @new_records += 1
    end

    MarketOrder.insert_all(new_record_data)
  end

  def update_old_records(old_records)
    old_records.each do |order|
      begin
        market_order = MarketOrder.find_by(albion_id: order["Id"])
        next if market_order.nil?

        market_order['price'] = order["UnitPriceSilver"]
        market_order['amount'] = order["Amount"]
        market_order['expires'] = order["Expires"]

        if market_order.changed?
          market_order.save
          @updated_records += 1
        else
          @unupdated_records += 1
        end
      rescue ActiveRecord::RecordNotFound
        @invalid_records += 1
      rescue ActiveRecord::StatementInvalid
        @invalid_records += 1
      end
    end
  end
end