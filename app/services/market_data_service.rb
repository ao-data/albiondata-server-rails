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

    data = MarketOrder.where(item_id: ids, updated_at: 1.days.ago..)
    data = data.where(location: locations) unless locations.empty?
    data = data.where(quality_level: qualities) unless qualities.empty?
    data = data.group('2 asc', '3 desc')
    data = data.select('CONCAT(item_id, "!!", location, "!!", quality_level) AS o_keey',
                             'CONCAT(item_id, "!!", location, "!!_", quality_level, "!!", auction_type) AS o_keey_at',
                             'FROM_UNIXTIME((UNIX_TIMESTAMP(updated_at) DIV 300 * 300), "%Y-%m-%dT%H:%i:%s") AS updated_at_binned',
                             'min(price) as min_price',
                             'max(price) as max_price',
                             'auction_type',
                             'item_id',
                             'location',
                             'quality_level')

    # build a hash of humanized cities for this call
    humanized_cities = {}
    locations.each do |location|
      humanized_cities[location] = humanize_city(location_to_city(location).to_s)
    end

    rows = []
    execution_time = Benchmark.measure do
      rows = MarketOrder.connection.select_rows(data.to_sql)
    end
    Rails.logger.info("Retriving data took #{execution_time.real} seconds")

    results = {}
    default_date = DateTime.new(0001, 1, 1, 0, 0, 0).strftime('%Y-%m-%dT%H:%M:%S')
    last_o_keey_at = nil
    execution_time = Benchmark.measure do
      rows.each do |result|
        o_keey, o_keey_at, updated_at_binned, min_price, max_price, auction_type, item_id, location, quality_level = result

        humanized_city = humanized_cities[location]
        city_key = o_keey.gsub("!!#{location.to_s}!!", "!!#{humanized_city}!!")

        next if last_o_keey_at == o_keey_at
        last_o_keey_at = o_keey_at

        results[city_key] ||= {item_id: item_id, city: humanized_city, quality: quality_level, sell_price_min: 0, sell_price_min_date: default_date, sell_price_max: 0, sell_price_max_date: default_date, buy_price_min: 0, buy_price_min_date: default_date, buy_price_max: 0, buy_price_max_date: default_date }
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
      location_strings = locations.map { |location| location_to_city(location) }
      ids.sort.product(location_strings.map{|s| humanize_city(s.to_s)}.sort, qualities.sort).map do |item_id, location, quality|
        key = "#{item_id}!!#{location}!!#{quality}"
        results[key] ||= {item_id: item_id, city: location, quality: quality}.merge(default_values)
      end
    end
    Rails.logger.info("Blanks processing took #{execution_time.real} seconds")

    results.values_at(*results.keys.sort)
  end
end
