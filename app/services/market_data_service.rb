class MarketDataService
  # called by api controller, which sets which database to use

  include Location
  include Quality

  def get_stats(params)
    # Notes: when using _ for the keys, T4_LEATHER_MARTLOCK comes after T4_LEATHER_LEVEL1@1_MARTLOCK because "T4_LEATHER_M" and "T4_LEATHER_L" sorting.
    # We don't want that. Key name separator is now !!.
    #
    # Split the provided parameters into separate variables
    ids, locations, qualities = params[:id].upcase.split(',').uniq, get_locations(params), get_qualities(params)

    since_bin = 1.day.ago.to_i / 300 * 300

    # Inner subquery: find the latest 5-minute bin per (item, location, quality, auction_type)
    latest_bins = MarketOrder.where(item_id: ids, updated_at_bin: since_bin..)
    latest_bins = latest_bins.where(location: locations) unless locations.empty?
    latest_bins = latest_bins.where(quality_level: qualities) unless qualities.empty?
    latest_bins = latest_bins
      .group(:item_id, :location, :quality_level, :auction_type)
      .select(:item_id, :location, :quality_level, :auction_type, 'MAX(updated_at_bin) AS max_bin')

    # Outer query: join to latest_bins to restrict to only that bin's records, then aggregate
    data = MarketOrder.joins("INNER JOIN (#{latest_bins.to_sql}) lb
                                ON market_orders.item_id       = lb.item_id
                               AND market_orders.location       = lb.location
                               AND market_orders.quality_level  = lb.quality_level
                               AND market_orders.auction_type   = lb.auction_type
                               AND market_orders.updated_at_bin = lb.max_bin")
                      .where(item_id: ids, updated_at_bin: since_bin..)
    data = data.where(location: locations) unless locations.empty?
    data = data.where(quality_level: qualities) unless qualities.empty?
    data = data
      .group('market_orders.item_id', 'market_orders.location', 'market_orders.quality_level', 'market_orders.auction_type', 'lb.max_bin')
      .select('market_orders.item_id', 'market_orders.location', 'market_orders.quality_level', 'market_orders.auction_type',
              'MIN(market_orders.price) AS min_price', 'MAX(market_orders.price) AS max_price',
              "FROM_UNIXTIME(lb.max_bin, '%Y-%m-%dT%H:%i:%s') AS updated_at_binned")

    # build a hash of humanized cities for this call
    humanized_cities = {}
    locations.each do |location|
      humanized_cities[location] = humanize_city(location_to_city(location).to_s)
    end

    rows = []
    execution_time = Benchmark.measure do
      rows = MarketOrder.connection.select_rows(data.to_sql)
    end
    Rails.logger.info("Retrieving data took #{execution_time.real} seconds")

    results = {}
    default_date = '0001-01-01T00:00:00'
    execution_time = Benchmark.measure do
      rows.each do |item_id, location, quality_level, auction_type, min_price, max_price, updated_at_binned|
        humanized_city = humanized_cities[location]
        city_key = "#{item_id}!!#{humanized_city}!!#{quality_level}"

        results[city_key] ||= { item_id: item_id, city: humanized_city, quality: quality_level, sell_price_min: 0, sell_price_min_date: default_date, sell_price_max: 0, sell_price_max_date: default_date, buy_price_min: 0, buy_price_min_date: default_date, buy_price_max: 0, buy_price_max_date: default_date }
        if auction_type == 'offer'
          results[city_key][:sell_price_min] = min_price
          results[city_key][:sell_price_min_date] = updated_at_binned
          results[city_key][:sell_price_max] = max_price
          results[city_key][:sell_price_max_date] = updated_at_binned
        else
          results[city_key][:buy_price_min] = min_price
          results[city_key][:buy_price_min_date] = updated_at_binned
          results[city_key][:buy_price_max] = max_price
          results[city_key][:buy_price_max_date] = updated_at_binned
        end
      end
    end
    Rails.logger.info("Data processing took #{execution_time.real} seconds")

    # fill in the blanks
    execution_time = Benchmark.measure do
      default_values = { sell_price_min: 0, sell_price_min_date: default_date, sell_price_max: 0, sell_price_max_date: default_date, buy_price_min: 0, buy_price_min_date: default_date, buy_price_max: 0, buy_price_max_date: default_date }
      humanized_location_strings = locations.map { |loc| humanized_cities[loc] }
      ids.sort.product(humanized_location_strings.sort, qualities.sort).each do |item_id, location, quality|
        key = "#{item_id}!!#{location}!!#{quality}"
        results[key] ||= { item_id: item_id, city: location, quality: quality }.merge(default_values)
      end
    end
    Rails.logger.info("Blanks processing took #{execution_time.real} seconds")

    results.values_at(*results.keys.sort)
  end
end
