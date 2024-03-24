class MarketDataService

  CITY_TO_LOCATION = {
    "SwampCross": 4,
    "Thetford": 7,
    "ThetfordPortal": 9,
    "MorganasRest": 8,
    "Lymhurst": 1002,
    "LymhurstPortal": 1301,
    "ForestCross": 1006,
    "MerlynsRest": 1012,
    "SteppeCross": 2002,
    "Bridgewatch": 2004,
    "BridgewatchPortal": 2301,
    "HighlandCross": 3002,
    "BlackMarket": 3003,
    "Caerleon": 3005,
    "Martlock": 3008,
    "MartlockPortal": 3301,
    "Caerleon2": 3013,
    "FortSterling": 4002,
    "FortSterlingPortal": 4301,
    "MountainCross": 4006,
    "ArthursRest": 4300,
    # "Brecilien": 5003,
  }

  LOCATION_TO_CITY = CITY_TO_LOCATION.invert.transform_keys(&:to_s)

  def location_to_city(location)
    LOCATION_TO_CITY[location.to_s] || location.to_s
  end

  def city_to_location(city)
    CITY_TO_LOCATION[city.to_sym] || city.to_i
  end

  def get_locations(params)
    params[:locations]&.split(',')&.map { |l| city_to_location(l) } || [3005, 5003]
  end

  def get_qualities(params)
    params[:qualities]&.split(',')&.map(&:to_i) || [1]
  end

  def prepare_empty_results(ids, locations, qualities)
    ids.sort.product(locations, qualities.sort).each_with_object({}) do |(id, location, quality), results|
      key = "#{id}_#{location}_#{quality}"
      results[key] = default_result.merge(item_id: id, city: location, quality: quality)
    end
  end

  def get_stats(params)
    # Split the provided parameters into separate variables
    ids, locations, qualities = params[:id].upcase.split(','), get_locations(params), get_qualities(params)

    # Prepare an empty results hash with default values
    results = prepare_empty_results(ids, locations, qualities)

    # Query the MarketOrder model for orders matching the provided parameters
    # Select necessary fields and order by the binned updated_at field
    orders = MarketOrder.where(item_id: ids, updated_at: 1.days.ago.., quality_level: qualities, location: locations)
       .select(:auction_type, :price,
               'concat(item_id, "_", location, "_", quality_level) as o_keey',
               'concat(item_id, "_", location, "_", quality_level, "_", auction_type) as o_keey_at',
               'FROM_UNIXTIME((UNIX_TIMESTAMP(updated_at) DIV 300 * 300), "%Y-%m-%dT%H:%i:%s") as updated_at_binned'
       ).order(updated_at_binned: :asc)

    # Iterate over each order
    MarketOrder.connection.select_rows(orders.to_sql).each do |order|
      # Destructure the order into separate variables
      auction_type, price, o_keey, o_keey_at, updated_at_binned = order

      # If the auction type is 'offer'
      if auction_type == 'offer'
        # If the binned updated_at is not the same as the current sell_price_min_date
        if updated_at_binned != results[o_keey][:sell_price_min_date]
          # Update the sell_price_min, sell_price_min_date, sell_price_max, and sell_price_max_date fields
          results[o_keey].merge!({sell_price_min: price, sell_price_min_date: updated_at_binned, sell_price_max: price, sell_price_max_date: updated_at_binned})
        else
          # Otherwise, update the sell_price_min and sell_price_max fields if necessary
          results[o_keey][:sell_price_min] = price if price < results[o_keey][:sell_price_min]
          results[o_keey][:sell_price_max] = price if price > results[o_keey][:sell_price_max]
        end
      # If the auction type is 'request'
      elsif auction_type == 'request'
        # If the binned updated_at is not the same as the current buy_price_min_date
        if updated_at_binned != results[o_keey][:buy_price_min_date]
          # Update the buy_price_min, buy_price_min_date, buy_price_max, and buy_price_max_date fields
          results[o_keey].merge!({buy_price_min: price, buy_price_min_date: updated_at_binned, buy_price_max: price, buy_price_max_date: updated_at_binned})
        else
          # Otherwise, update the buy_price_min and buy_price_max fields if necessary
          results[o_keey][:buy_price_min] = price if price < results[o_keey][:buy_price_min]
          results[o_keey][:buy_price_max] = price if price > results[o_keey][:buy_price_max]
        end
      end
    end

    # Sort the results and return them
    sorted_results = sort_results(ids, locations, qualities, results)

    sorted_results
  end

  def sort_results(ids, locations, qualities, results)
    # Convert location ids to city names
    location_strings = locations.map { |location| location_to_city(location) }

    # Define a default date
    default_date = DateTime.new(0001, 1, 1, 0, 0, 0).strftime('%Y-%m-%dT%H:%M:%S')
    # Define default values for the market data
    default_values = { sell_price_min_date: default_date, sell_price_min: 0, sell_price_max_date: default_date, sell_price_max: 0, buy_price_min_date: default_date, buy_price_min: 0, buy_price_max_date: default_date, buy_price_max: 0 }

    # Generate sorted results by iterating over all combinations of ids, location_strings, and qualities
    sorted_results = ids.sort.product(location_strings.map{|s| s.to_s}.sort, qualities.sort).map do |id, location, quality|
      # Generate a key for each combination
      key = "#{id}_#{city_to_location(location)}_#{quality}"
      # Merge the city into the result
      result = results[key].merge(city: location)
      # Merge the default values into the result, preserving existing values
      result.merge(default_values) { |_key, oldval, _newval| oldval || _newval }
    end

    # Return the sorted results
    sorted_results
  end

  def default_result
    %i[item_id city quality sell_price_min sell_price_min_date sell_price_max sell_price_max_date buy_price_min buy_price_min_date buy_price_max buy_price_max_date].index_with(nil)
  end
end
