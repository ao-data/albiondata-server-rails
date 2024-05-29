class MarketOrderProcessorService

  def initialize(orders, server_id, opts)
    @orders = orders
    @server_id = server_id
    @opts = opts
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
    record_data = []
    @orders.each do |order|
      expires = DateTime.parse(order['Expires'])
      expires = DateTime.now + 1.month if expires.year > 2050 # black market expires "never expire", so we fake it

      record_data << {
        albion_id: order["Id"],
        item_id: order["ItemTypeId"],
        quality_level: order["QualityLevel"],
        enchantment_level: order["EnchantmentLevel"],
        price: order["UnitPriceSilver"],
        initial_amount: order["Amount"],
        amount: order["Amount"],
        auction_type: order["AuctionType"],
        expires: expires,
        location: order["LocationId"],
        updated_at: DateTime.now
      }
    end

    # logs
    log = { class: 'MarketOrderProcessorService', method: 'process', data: @orders,
            server_id: @server_id, opts: @opts, record_data: record_data }
    Sidekiq.logger.info(log.to_json)

    MarketOrder.upsert_all(record_data, update_only: [:price, :amount, :expires, :updated_at])
  end
end