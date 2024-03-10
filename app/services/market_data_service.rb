class MarketDataService

  def initialize(params)
    @params = params
  end

  def params
    @params
  end

  C2L = {
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

  L2C = {
    "4": "SwampCross",
    "7": "Thetford",
    "9": "ThetfordPortal",
    "8": "MorganasRest",
    "1002": "Lymhurst",
    "1031": "LymhurstPortal",
    "1006": "ForestCross",
    "1012": "MerlynsRest",
    "2002": "SteppeCross",
    "2004": "Bridgewatch",
    "2301": "BridgewatchPortal",
    "3002": "HighlandCross",
    "3003": "BlackMarket",
    "3005": "Caerleon",
    "3008": "Martlock",
    "3301": "MartlockPortal",
    "3013": "Caerleon2",
    "4002": "FortSterling",
    "4301": "FortSterlingPortal",
    "4006": "MountainCross",
    "4300": "ArthursRest",
    # "5003": "Brecilien"
  }

  def location_to_city(location)
    (L2C.key?(location.to_s.to_sym) ? L2C[location.to_s.to_sym] : location.to_s)
  end

  def city_to_location(city)
    (C2L.key?(city.to_sym) ? C2L[city.to_sym] : city.to_i)
  end

  def get_locations(params)
    # parse any city name strings to location ids
    locations = params[:locations].split(',').each.map{|l| city_to_location(l) } if params.key?(:locations)

    # set default locations to search, if none are sent in the query string
    locations = [3005,5003].each.map{|l| l.to_i } if locations.nil?

    # now map all locations to city names, for result array/hash sorting purposes
    # locations = locations.each.map{|l| location_to_city(l)}

    locations
  end

  def get_qualities(params)
      # parse any qualitiles
      qualities = params[:qualities].split(',').each.map{|q| q.to_i} if params.key?(:qualities)

      # set default qualities, if none are sent in the query string
      qualities = [1] if qualities.nil?

      qualities
  end

  def prepare_emtpy_results(ids, locations, qualities)
    results = {}

    ids.sort.each do |id|
      locations.each do |location|
        qualities.sort.each do |quality|
          k = "#{id}_#{location}_#{quality}"

          result = default_result
          result[:item_id] = id
          result[:city] = location
          result[:quality] = quality
          results[k] = result
        end
      end
    end

    results
  end

  def get_stats
    ids = params[:id].split(',')
    locations = get_locations(params)
    qualities = get_qualities(params)
    results = prepare_emtpy_results(ids, locations, qualities)

    # filter = MarketOrder
    # filter = filter.where(item_id: ids, updated_at: 1.days.ago.., quality_level: qualities, location: locations)
    # filter = filter.select(:auction_type)
    # filter = filter.select('concat(item_id, "_", location, "_", quality_level, "_", auction_type) as o_keey')
    # filter = filter.select('concat(item_id, "_", location, "_", quality_level, "_", auction_type, "_", (UNIX_TIMESTAMP(updated_at) DIV 300 * 300)) as o_keey_binned')
    # filter = filter.group('concat(item_id, "_", location, "_", quality_level, "_", auction_type, "_", (UNIX_TIMESTAMP(updated_at) DIV 300 * 300))')
    # # filter_sql = "\n\nselect max(o_keey_binned) as o_key_binned from (\n\n#{filter.to_sql}\n\n) as a group by o_keey\n\n"
    # filter_sql = "'#{filter.each.map{|f|f.o_keey_binned}.join("','")}'"

    orders = MarketOrder
    orders = orders.where(item_id: ids, updated_at: 1.days.ago.., quality_level: qualities, location: locations)
    orders = orders.select(:auction_type, :price)
    orders = orders.select('concat(item_id, "_", location, "_", quality_level) as o_keey')
    orders = orders.select('concat(item_id, "_", location, "_", quality_level, "_", auction_type) as o_keey_at')
    orders = orders.select('FROM_UNIXTIME((UNIX_TIMESTAMP(updated_at) DIV 300 * 300), "%Y-%m-%dT%H:%i:%s") as updated_at_binned')
    orders = orders.order(updated_at_binned: :asc)
    # orders = orders.where('concat(item_id, "_", location, "_", quality_level, "_", auction_type, "_", (UNIX_TIMESTAMP(updated_at) DIV 300 * 300)) in (' + filter_sql + ')')

    last_offer_binned = nil
    last_request_binned = nil
    MarketOrder.connection.select_rows(orders.to_sql).each do |order|
      auction_type = order[0]
      price = order[1]
      o_keey = order[2]
      o_keey_at = order[3]
      updated_at_binned = order[4]

      if auction_type == 'offer'
        # sell

        if last_offer_binned != updated_at_binned
          last_offer_binned = updated_at_binned
          results[o_keey].merge!({sell_price_min: 999999999, sell_price_min_date: updated_at_binned})
          results[o_keey].merge!({sell_price_max: 0, sell_price_max_date: updated_at_binned})
        end

        results[o_keey].merge!({sell_price_min: price, sell_price_min_date: updated_at_binned}) if price < results[o_keey][:sell_price_min]
        results[o_keey].merge!({sell_price_max: price, sell_price_max_date: updated_at_binned}) if price > results[o_keey][:sell_price_max]
      elsif auction_type == 'request'
        # buy

        if last_request_binned != updated_at_binned
          last_request_binned = updated_at_binned
          results[o_keey].merge!({buy_price_min: 999999999, buy_price_min_date: updated_at_binned})
          results[o_keey].merge!({buy_price_max: 0, buy_price_max_date: updated_at_binned})
        end

        results[o_keey].merge!({buy_price_min: price, buy_price_min_date: updated_at_binned}) if price < results[o_keey][:buy_price_min]
        results[o_keey].merge!({buy_price_max: price, buy_price_max_date: updated_at_binned}) if price > results[o_keey][:buy_price_max]
      end
    end

    sorted_results = sort_results(ids, locations, qualities, results)

    sorted_results
  end

  def sort_results(ids, locations, qualities, results)
    location_strings = []
    locations.each do |location|
      location_strings << location_to_city(location)
    end

    sorted_results = []
    default_date = DateTime.new(0001, 1, 1, 0, 0, 0).strftime('%Y-%m-%dT%H:%M:%S')
    ids.sort.each do |id|
      location_strings.sort.each do |location|
        qualities.sort.each do |quality|
          k = "#{id}_#{city_to_location(location)}_#{quality}"
          result = results[k].merge!({city: location})
          result.merge!({ sell_price_min_date: default_date, sell_price_min: 0 }) if result[:sell_price_min_date].nil?
          result.merge!({ sell_price_max_date: default_date, sell_price_max: 0 }) if result[:sell_price_max_date].nil?
          result.merge!({ buy_price_min_date: default_date, buy_price_min: 0 }) if result[:buy_price_min_date].nil?
          result.merge!({ buy_price_max_date: default_date, buy_price_max: 0 }) if result[:buy_price_max_date].nil?
          sorted_results << result
        end
      end
    end

    sorted_results
  end

  def default_result
    {
      item_id: nil,
      city: nil,
      quality: nil,
      sell_price_min: 999999999999,
      sell_price_min_date: nil,
      sell_price_max: 0,
      sell_price_max_date: nil,
      buy_price_min: 999999999999,
      buy_price_min_date: nil,
      buy_price_max: 0,
      buy_price_max_date: nil,
    }
  end

end
