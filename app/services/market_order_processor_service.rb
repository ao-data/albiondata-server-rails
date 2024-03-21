class MarketOrderProcessorService

  def initialize(orders)
    @orders = orders
    @new_records = 0
    @redis_duplicates = 0
    @duplicate_records = 0
    @invalid_records = 0
    @updated_records = 0
    @unupdated_records = 0
  end

  def process
    new_records = []
    old_records = []

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

    # remove duplicates found in redis, 24 hour based
    redis_deduped = []
    @orders.each do |order|
      begin
        sha256 = Digest::SHA256.hexdigest(order.to_s)
        if REDIS.get("RECORD_SHA256_24H:#{sha256}").nil?
          REDIS.set("RECORD_SHA256_24H:#{sha256}", 1, ex: 86400)
          redis_deduped << order
        else
          @redis_duplicates += 1
        end
      end
    end

    # separate new and old records
    alibon_ids = @orders.map { |order| order["Id"] }
    found_albion_ids = MarketOrder.where(albion_id: alibon_ids).pluck(:albion_id)

    @orders.each do |order|
      if found_albion_ids.include?(order["Id"])
        old_records << order
      else
        new_records << order
      end
    end

    # add new records
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

    # update old records
    old_records.each do |order|
      begin
        market_order = MarketOrder.find_by(albion_id: order["Id"])
        next if market_order.nil?

        market_order.attributes.merge!(
          price: order["UnitPriceSilver"],
          amount: order["Amount"],
          expires: order["Expires"]
        )

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

    puts ''
    puts "MarketOrderProcessorService: New records: #{@new_records}, Duplicate records: #{@duplicate_records}, Updated records: #{@updated_records}, Unupdated records: #{@unupdated_records}, Invalid records: #{@invalid_records}, Redis duplicates: #{@redis_duplicates}"
    puts ''
  end
end