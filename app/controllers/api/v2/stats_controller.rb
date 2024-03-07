class API::V2::StatsController < API::V2::APIController
  def index
    url1 = "http://localhost:3000/api/v2/stats/prices/T2_HEAD_LEATHER_SET1,T2_HEAD_LEATHER_SET2,T2_HEAD_LEATHER_SET3,T2_HEAD_LEATHER_MORGANA,T2_HEAD_LEATHER_HELL,T2_HEAD_LEATHER_UNDEAD,T2_HEAD_LEATHER_FEY,T2_HEAD_LEATHER_AVALON,,T3_HEAD_LEATHER_SET1,T3_HEAD_LEATHER_SET2,T3_HEAD_LEATHER_SET3,T3_HEAD_LEATHER_MORGANA,T3_HEAD_LEATHER_HELL,T3_HEAD_LEATHER_UNDEAD,T3_HEAD_LEATHER_FEY,T3_HEAD_LEATHER_AVALON,,T4_HEAD_LEATHER_SET1,T4_HEAD_LEATHER_SET2,T4_HEAD_LEATHER_SET3,T4_HEAD_LEATHER_MORGANA,T4_HEAD_LEATHER_HELL,T4_HEAD_LEATHER_UNDEAD,T4_HEAD_LEATHER_FEY,T4_HEAD_LEATHER_AVALON,,T4_HEAD_LEATHER_SET1@1,T4_HEAD_LEATHER_SET2@1,T4_HEAD_LEATHER_SET3@1,T4_HEAD_LEATHER_MORGANA@1,T4_HEAD_LEATHER_HELL@1,T4_HEAD_LEATHER_UNDEAD@1,T4_HEAD_LEATHER_FEY@1,T4_HEAD_LEATHER_AVALON@1,,T4_HEAD_LEATHER_SET1@2,T4_HEAD_LEATHER_SET2@2,T4_HEAD_LEATHER_SET3@2,T4_HEAD_LEATHER_MORGANA@2,T4_HEAD_LEATHER_HELL@2,T4_HEAD_LEATHER_UNDEAD@2,T4_HEAD_LEATHER_FEY@2,T4_HEAD_LEATHER_AVALON@2,,T4_HEAD_LEATHER_SET1@3,T4_HEAD_LEATHER_SET2@3,T4_HEAD_LEATHER_SET3@3,T4_HEAD_LEATHER_MORGANA@3,T4_HEAD_LEATHER_HELL@3,T4_HEAD_LEATHER_UNDEAD@3,T4_HEAD_LEATHER_FEY@3,T4_HEAD_LEATHER_AVALON@3,,T4_HEAD_LEATHER_SET1@4,T4_HEAD_LEATHER_SET2@4,T4_HEAD_LEATHER_SET3@4,T4_HEAD_LEATHER_MORGANA@4,T4_HEAD_LEATHER_HELL@4,T4_HEAD_LEATHER_UNDEAD@4,T4_HEAD_LEATHER_FEY@4,T4_HEAD_LEATHER_AVALON@4,,T5_HEAD_LEATHER_SET1,T5_HEAD_LEATHER_SET2,T5_HEAD_LEATHER_SET3,T5_HEAD_LEATHER_MORGANA,T5_HEAD_LEATHER_HELL,T5_HEAD_LEATHER_UNDEAD,T5_HEAD_LEATHER_FEY,T5_HEAD_LEATHER_AVALON,,T5_HEAD_LEATHER_SET1@1,T5_HEAD_LEATHER_SET2@1,T5_HEAD_LEATHER_SET3@1,T5_HEAD_LEATHER_MORGANA@1,T5_HEAD_LEATHER_HELL@1,T5_HEAD_LEATHER_UNDEAD@1,T5_HEAD_LEATHER_FEY@1,T5_HEAD_LEATHER_AVALON@1,,T5_HEAD_LEATHER_SET1@2,T5_HEAD_LEATHER_SET2@2,T5_HEAD_LEATHER_SET3@2,T5_HEAD_LEATHER_MORGANA@2,T5_HEAD_LEATHER_HELL@2,T5_HEAD_LEATHER_UNDEAD@2,T5_HEAD_LEATHER_FEY@2,T5_HEAD_LEATHER_AVALON@2,,T5_HEAD_LEATHER_SET1@3,T5_HEAD_LEATHER_SET2@3,T5_HEAD_LEATHER_SET3@3,T5_HEAD_LEATHER_MORGANA@3,T5_HEAD_LEATHER_HELL@3,T5_HEAD_LEATHER_UNDEAD@3,T5_HEAD_LEATHER_FEY@3,T5_HEAD_LEATHER_AVALON@3,,T5_HEAD_LEATHER_SET1@4,T5_HEAD_LEATHER_SET2@4,T5_HEAD_LEATHER_SET3@4,T5_HEAD_LEATHER_MORGANA@4,T5_HEAD_LEATHER_HELL@4,T5_HEAD_LEATHER_UNDEAD@4,T5_HEAD_LEATHER_FEY@4,T5_HEAD_LEATHER_AVALON@4,,T6_HEAD_LEATHER_SET1,T6_HEAD_LEATHER_SET2,T6_HEAD_LEATHER_SET3,T6_HEAD_LEATHER_MORGANA,T6_HEAD_LEATHER_HELL,T6_HEAD_LEATHER_UNDEAD,T6_HEAD_LEATHER_FEY,T6_HEAD_LEATHER_AVALON,,T6_HEAD_LEATHER_SET1@1,T6_HEAD_LEATHER_SET2@1,T6_HEAD_LEATHER_SET3@1,T6_HEAD_LEATHER_MORGANA@1,T6_HEAD_LEATHER_HELL@1,T6_HEAD_LEATHER_UNDEAD@1,T6_HEAD_LEATHER_FEY@1,T6_HEAD_LEATHER_AVALON@1,?locations=5003,3005&qualities=2"
    url2 = "https://west.albion-online-data.com/api/v2/stats/prices/T2_HEAD_LEATHER_SET1,T2_HEAD_LEATHER_SET2,T2_HEAD_LEATHER_SET3,T2_HEAD_LEATHER_MORGANA,T2_HEAD_LEATHER_HELL,T2_HEAD_LEATHER_UNDEAD,T2_HEAD_LEATHER_FEY,T2_HEAD_LEATHER_AVALON,,T3_HEAD_LEATHER_SET1,T3_HEAD_LEATHER_SET2,T3_HEAD_LEATHER_SET3,T3_HEAD_LEATHER_MORGANA,T3_HEAD_LEATHER_HELL,T3_HEAD_LEATHER_UNDEAD,T3_HEAD_LEATHER_FEY,T3_HEAD_LEATHER_AVALON,,T4_HEAD_LEATHER_SET1,T4_HEAD_LEATHER_SET2,T4_HEAD_LEATHER_SET3,T4_HEAD_LEATHER_MORGANA,T4_HEAD_LEATHER_HELL,T4_HEAD_LEATHER_UNDEAD,T4_HEAD_LEATHER_FEY,T4_HEAD_LEATHER_AVALON,,T4_HEAD_LEATHER_SET1@1,T4_HEAD_LEATHER_SET2@1,T4_HEAD_LEATHER_SET3@1,T4_HEAD_LEATHER_MORGANA@1,T4_HEAD_LEATHER_HELL@1,T4_HEAD_LEATHER_UNDEAD@1,T4_HEAD_LEATHER_FEY@1,T4_HEAD_LEATHER_AVALON@1,,T4_HEAD_LEATHER_SET1@2,T4_HEAD_LEATHER_SET2@2,T4_HEAD_LEATHER_SET3@2,T4_HEAD_LEATHER_MORGANA@2,T4_HEAD_LEATHER_HELL@2,T4_HEAD_LEATHER_UNDEAD@2,T4_HEAD_LEATHER_FEY@2,T4_HEAD_LEATHER_AVALON@2,,T4_HEAD_LEATHER_SET1@3,T4_HEAD_LEATHER_SET2@3,T4_HEAD_LEATHER_SET3@3,T4_HEAD_LEATHER_MORGANA@3,T4_HEAD_LEATHER_HELL@3,T4_HEAD_LEATHER_UNDEAD@3,T4_HEAD_LEATHER_FEY@3,T4_HEAD_LEATHER_AVALON@3,,T4_HEAD_LEATHER_SET1@4,T4_HEAD_LEATHER_SET2@4,T4_HEAD_LEATHER_SET3@4,T4_HEAD_LEATHER_MORGANA@4,T4_HEAD_LEATHER_HELL@4,T4_HEAD_LEATHER_UNDEAD@4,T4_HEAD_LEATHER_FEY@4,T4_HEAD_LEATHER_AVALON@4,,T5_HEAD_LEATHER_SET1,T5_HEAD_LEATHER_SET2,T5_HEAD_LEATHER_SET3,T5_HEAD_LEATHER_MORGANA,T5_HEAD_LEATHER_HELL,T5_HEAD_LEATHER_UNDEAD,T5_HEAD_LEATHER_FEY,T5_HEAD_LEATHER_AVALON,,T5_HEAD_LEATHER_SET1@1,T5_HEAD_LEATHER_SET2@1,T5_HEAD_LEATHER_SET3@1,T5_HEAD_LEATHER_MORGANA@1,T5_HEAD_LEATHER_HELL@1,T5_HEAD_LEATHER_UNDEAD@1,T5_HEAD_LEATHER_FEY@1,T5_HEAD_LEATHER_AVALON@1,,T5_HEAD_LEATHER_SET1@2,T5_HEAD_LEATHER_SET2@2,T5_HEAD_LEATHER_SET3@2,T5_HEAD_LEATHER_MORGANA@2,T5_HEAD_LEATHER_HELL@2,T5_HEAD_LEATHER_UNDEAD@2,T5_HEAD_LEATHER_FEY@2,T5_HEAD_LEATHER_AVALON@2,,T5_HEAD_LEATHER_SET1@3,T5_HEAD_LEATHER_SET2@3,T5_HEAD_LEATHER_SET3@3,T5_HEAD_LEATHER_MORGANA@3,T5_HEAD_LEATHER_HELL@3,T5_HEAD_LEATHER_UNDEAD@3,T5_HEAD_LEATHER_FEY@3,T5_HEAD_LEATHER_AVALON@3,,T5_HEAD_LEATHER_SET1@4,T5_HEAD_LEATHER_SET2@4,T5_HEAD_LEATHER_SET3@4,T5_HEAD_LEATHER_MORGANA@4,T5_HEAD_LEATHER_HELL@4,T5_HEAD_LEATHER_UNDEAD@4,T5_HEAD_LEATHER_FEY@4,T5_HEAD_LEATHER_AVALON@4,,T6_HEAD_LEATHER_SET1,T6_HEAD_LEATHER_SET2,T6_HEAD_LEATHER_SET3,T6_HEAD_LEATHER_MORGANA,T6_HEAD_LEATHER_HELL,T6_HEAD_LEATHER_UNDEAD,T6_HEAD_LEATHER_FEY,T6_HEAD_LEATHER_AVALON,,T6_HEAD_LEATHER_SET1@1,T6_HEAD_LEATHER_SET2@1,T6_HEAD_LEATHER_SET3@1,T6_HEAD_LEATHER_MORGANA@1,T6_HEAD_LEATHER_HELL@1,T6_HEAD_LEATHER_UNDEAD@1,T6_HEAD_LEATHER_FEY@1,T6_HEAD_LEATHER_AVALON@1,?locations=5003,3005&qualities=2"


    render json: [url1, url2].to_json
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

    filter = MarketOrder
    filter = filter.where(item_id: ids, updated_at: 1.days.ago.., quality_level: qualities, location: locations)
    filter = filter.select(:auction_type)
    filter = filter.select('concat(item_id, "_", location, "_", quality_level, "_", auction_type) as o_keey')
    filter = filter.select('concat(item_id, "_", location, "_", quality_level, "_", auction_type, "_", (UNIX_TIMESTAMP(updated_at) DIV 300 * 300)) as o_keey_binned')
    filter = filter.group('concat(item_id, "_", location, "_", quality_level, "_", auction_type, "_", (UNIX_TIMESTAMP(updated_at) DIV 300 * 300))')
    filter_sql = "select max(o_keey_binned) as o_key_binned from (\n\n#{filter.to_sql}\n\n) as a group by o_keey"

    orders = MarketOrder
    orders = orders.where(item_id: ids, updated_at: 1.days.ago.., quality_level: qualities, location: locations)
    orders = orders.select(:auction_type, :price)
    orders = orders.select('concat(item_id, "_", location, "_", quality_level) as o_keey')
    orders = orders.select('FROM_UNIXTIME((UNIX_TIMESTAMP(updated_at) DIV 300 * 300), "%Y-%m-%dT%H:%i:%s") as updated_at_binned')
    orders = orders.where('concat(item_id, "_", location, "_", quality_level, "_", auction_type, "_", (UNIX_TIMESTAMP(updated_at) DIV 300 * 300)) in (' + filter_sql + ')')

    orders.each do |order|
      if order[:auction_type] == 'offer'
        # sell
        results[order.o_keey].merge!({sell_price_min: order[:price], sell_price_min_date: order.updated_at_binned}) if order[:price] < results[order.o_keey][:sell_price_min]
        results[order.o_keey].merge!({sell_price_max: order[:price], sell_price_max_date: order.updated_at_binned}) if order[:price] > results[order.o_keey][:sell_price_max]

      elsif order[:auction_type] == 'request'
        # buy
        results[order.o_keey].merge!({buy_price_min: order[:price], buy_price_min_date: order.updated_at_binned}) if order[:price] < results[order.o_keey][:buy_price_min]
        results[order.o_keey].merge!({buy_price_max: order[:price], buy_price_max_date: order.updated_at_binned}) if order[:price] > results[order.o_keey][:buy_price_max]
      end

    end

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

  def show_table
    sorted_results = get_stats

    fields = [:item_id, :city, :quality, :sell_price_min, :sell_price_min_date, :sell_price_max,
              :sell_price_max_date, :buy_price_min, :buy_price_min_date, :buy_price_max, :buy_price_max_date]

    rows = []
    rows << "<head><style>table, th, td {border: 1px solid black;border-collapse: collapse;}</style></head><body>"
    rows << "<table style='width:100%'>"
    rows << "<tr>"
    fields.each do |f|
      rows << "<th>#{f.to_s}</th>"
    end
    rows << "</tr>"


    default_date = DateTime.new(0001, 1, 1, 0, 0, 0).strftime('%Y-%m-%dT%H:%M:%S')
    sorted_results.each do |r|
      row = []
      row << "<tr>"
      fields.each do |f|
        row << (r[f] == 0 || r[f] == default_date ? "<td></td>" : "<td>#{r[f]}</td>")
      end
      row << "</tr>"
      rows << row.join('')
    end
    rows << "</table></body>"
    html = rows.join('')

    render html: html.html_safe
  end

  def show_json
    sorted_results = get_stats
    render json: sorted_results
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
