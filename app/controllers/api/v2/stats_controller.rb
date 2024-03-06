class API::V2::StatsController < API::V2::APIController
  def index
    url1 = "http://localhost:3000/api/v2/stats/prices/T2_HEAD_LEATHER_SET1,T2_HEAD_LEATHER_SET2,T2_HEAD_LEATHER_SET3,T2_HEAD_LEATHER_MORGANA,T2_HEAD_LEATHER_HELL,T2_HEAD_LEATHER_UNDEAD,T2_HEAD_LEATHER_FEY,T2_HEAD_LEATHER_AVALON,,T3_HEAD_LEATHER_SET1,T3_HEAD_LEATHER_SET2,T3_HEAD_LEATHER_SET3,T3_HEAD_LEATHER_MORGANA,T3_HEAD_LEATHER_HELL,T3_HEAD_LEATHER_UNDEAD,T3_HEAD_LEATHER_FEY,T3_HEAD_LEATHER_AVALON,,T4_HEAD_LEATHER_SET1,T4_HEAD_LEATHER_SET2,T4_HEAD_LEATHER_SET3,T4_HEAD_LEATHER_MORGANA,T4_HEAD_LEATHER_HELL,T4_HEAD_LEATHER_UNDEAD,T4_HEAD_LEATHER_FEY,T4_HEAD_LEATHER_AVALON,,T4_HEAD_LEATHER_SET1@1,T4_HEAD_LEATHER_SET2@1,T4_HEAD_LEATHER_SET3@1,T4_HEAD_LEATHER_MORGANA@1,T4_HEAD_LEATHER_HELL@1,T4_HEAD_LEATHER_UNDEAD@1,T4_HEAD_LEATHER_FEY@1,T4_HEAD_LEATHER_AVALON@1,,T4_HEAD_LEATHER_SET1@2,T4_HEAD_LEATHER_SET2@2,T4_HEAD_LEATHER_SET3@2,T4_HEAD_LEATHER_MORGANA@2,T4_HEAD_LEATHER_HELL@2,T4_HEAD_LEATHER_UNDEAD@2,T4_HEAD_LEATHER_FEY@2,T4_HEAD_LEATHER_AVALON@2,,T4_HEAD_LEATHER_SET1@3,T4_HEAD_LEATHER_SET2@3,T4_HEAD_LEATHER_SET3@3,T4_HEAD_LEATHER_MORGANA@3,T4_HEAD_LEATHER_HELL@3,T4_HEAD_LEATHER_UNDEAD@3,T4_HEAD_LEATHER_FEY@3,T4_HEAD_LEATHER_AVALON@3,,T4_HEAD_LEATHER_SET1@4,T4_HEAD_LEATHER_SET2@4,T4_HEAD_LEATHER_SET3@4,T4_HEAD_LEATHER_MORGANA@4,T4_HEAD_LEATHER_HELL@4,T4_HEAD_LEATHER_UNDEAD@4,T4_HEAD_LEATHER_FEY@4,T4_HEAD_LEATHER_AVALON@4,,T5_HEAD_LEATHER_SET1,T5_HEAD_LEATHER_SET2,T5_HEAD_LEATHER_SET3,T5_HEAD_LEATHER_MORGANA,T5_HEAD_LEATHER_HELL,T5_HEAD_LEATHER_UNDEAD,T5_HEAD_LEATHER_FEY,T5_HEAD_LEATHER_AVALON,,T5_HEAD_LEATHER_SET1@1,T5_HEAD_LEATHER_SET2@1,T5_HEAD_LEATHER_SET3@1,T5_HEAD_LEATHER_MORGANA@1,T5_HEAD_LEATHER_HELL@1,T5_HEAD_LEATHER_UNDEAD@1,T5_HEAD_LEATHER_FEY@1,T5_HEAD_LEATHER_AVALON@1,,T5_HEAD_LEATHER_SET1@2,T5_HEAD_LEATHER_SET2@2,T5_HEAD_LEATHER_SET3@2,T5_HEAD_LEATHER_MORGANA@2,T5_HEAD_LEATHER_HELL@2,T5_HEAD_LEATHER_UNDEAD@2,T5_HEAD_LEATHER_FEY@2,T5_HEAD_LEATHER_AVALON@2,,T5_HEAD_LEATHER_SET1@3,T5_HEAD_LEATHER_SET2@3,T5_HEAD_LEATHER_SET3@3,T5_HEAD_LEATHER_MORGANA@3,T5_HEAD_LEATHER_HELL@3,T5_HEAD_LEATHER_UNDEAD@3,T5_HEAD_LEATHER_FEY@3,T5_HEAD_LEATHER_AVALON@3,,T5_HEAD_LEATHER_SET1@4,T5_HEAD_LEATHER_SET2@4,T5_HEAD_LEATHER_SET3@4,T5_HEAD_LEATHER_MORGANA@4,T5_HEAD_LEATHER_HELL@4,T5_HEAD_LEATHER_UNDEAD@4,T5_HEAD_LEATHER_FEY@4,T5_HEAD_LEATHER_AVALON@4,,T6_HEAD_LEATHER_SET1,T6_HEAD_LEATHER_SET2,T6_HEAD_LEATHER_SET3,T6_HEAD_LEATHER_MORGANA,T6_HEAD_LEATHER_HELL,T6_HEAD_LEATHER_UNDEAD,T6_HEAD_LEATHER_FEY,T6_HEAD_LEATHER_AVALON,,T6_HEAD_LEATHER_SET1@1,T6_HEAD_LEATHER_SET2@1,T6_HEAD_LEATHER_SET3@1,T6_HEAD_LEATHER_MORGANA@1,T6_HEAD_LEATHER_HELL@1,T6_HEAD_LEATHER_UNDEAD@1,T6_HEAD_LEATHER_FEY@1,T6_HEAD_LEATHER_AVALON@1,?locations=5003,3005&qualities=2"
    url2 = "https://west.albion-online-data.com/api/v2/stats/prices/T2_HEAD_LEATHER_SET1,T2_HEAD_LEATHER_SET2,T2_HEAD_LEATHER_SET3,T2_HEAD_LEATHER_MORGANA,T2_HEAD_LEATHER_HELL,T2_HEAD_LEATHER_UNDEAD,T2_HEAD_LEATHER_FEY,T2_HEAD_LEATHER_AVALON,,T3_HEAD_LEATHER_SET1,T3_HEAD_LEATHER_SET2,T3_HEAD_LEATHER_SET3,T3_HEAD_LEATHER_MORGANA,T3_HEAD_LEATHER_HELL,T3_HEAD_LEATHER_UNDEAD,T3_HEAD_LEATHER_FEY,T3_HEAD_LEATHER_AVALON,,T4_HEAD_LEATHER_SET1,T4_HEAD_LEATHER_SET2,T4_HEAD_LEATHER_SET3,T4_HEAD_LEATHER_MORGANA,T4_HEAD_LEATHER_HELL,T4_HEAD_LEATHER_UNDEAD,T4_HEAD_LEATHER_FEY,T4_HEAD_LEATHER_AVALON,,T4_HEAD_LEATHER_SET1@1,T4_HEAD_LEATHER_SET2@1,T4_HEAD_LEATHER_SET3@1,T4_HEAD_LEATHER_MORGANA@1,T4_HEAD_LEATHER_HELL@1,T4_HEAD_LEATHER_UNDEAD@1,T4_HEAD_LEATHER_FEY@1,T4_HEAD_LEATHER_AVALON@1,,T4_HEAD_LEATHER_SET1@2,T4_HEAD_LEATHER_SET2@2,T4_HEAD_LEATHER_SET3@2,T4_HEAD_LEATHER_MORGANA@2,T4_HEAD_LEATHER_HELL@2,T4_HEAD_LEATHER_UNDEAD@2,T4_HEAD_LEATHER_FEY@2,T4_HEAD_LEATHER_AVALON@2,,T4_HEAD_LEATHER_SET1@3,T4_HEAD_LEATHER_SET2@3,T4_HEAD_LEATHER_SET3@3,T4_HEAD_LEATHER_MORGANA@3,T4_HEAD_LEATHER_HELL@3,T4_HEAD_LEATHER_UNDEAD@3,T4_HEAD_LEATHER_FEY@3,T4_HEAD_LEATHER_AVALON@3,,T4_HEAD_LEATHER_SET1@4,T4_HEAD_LEATHER_SET2@4,T4_HEAD_LEATHER_SET3@4,T4_HEAD_LEATHER_MORGANA@4,T4_HEAD_LEATHER_HELL@4,T4_HEAD_LEATHER_UNDEAD@4,T4_HEAD_LEATHER_FEY@4,T4_HEAD_LEATHER_AVALON@4,,T5_HEAD_LEATHER_SET1,T5_HEAD_LEATHER_SET2,T5_HEAD_LEATHER_SET3,T5_HEAD_LEATHER_MORGANA,T5_HEAD_LEATHER_HELL,T5_HEAD_LEATHER_UNDEAD,T5_HEAD_LEATHER_FEY,T5_HEAD_LEATHER_AVALON,,T5_HEAD_LEATHER_SET1@1,T5_HEAD_LEATHER_SET2@1,T5_HEAD_LEATHER_SET3@1,T5_HEAD_LEATHER_MORGANA@1,T5_HEAD_LEATHER_HELL@1,T5_HEAD_LEATHER_UNDEAD@1,T5_HEAD_LEATHER_FEY@1,T5_HEAD_LEATHER_AVALON@1,,T5_HEAD_LEATHER_SET1@2,T5_HEAD_LEATHER_SET2@2,T5_HEAD_LEATHER_SET3@2,T5_HEAD_LEATHER_MORGANA@2,T5_HEAD_LEATHER_HELL@2,T5_HEAD_LEATHER_UNDEAD@2,T5_HEAD_LEATHER_FEY@2,T5_HEAD_LEATHER_AVALON@2,,T5_HEAD_LEATHER_SET1@3,T5_HEAD_LEATHER_SET2@3,T5_HEAD_LEATHER_SET3@3,T5_HEAD_LEATHER_MORGANA@3,T5_HEAD_LEATHER_HELL@3,T5_HEAD_LEATHER_UNDEAD@3,T5_HEAD_LEATHER_FEY@3,T5_HEAD_LEATHER_AVALON@3,,T5_HEAD_LEATHER_SET1@4,T5_HEAD_LEATHER_SET2@4,T5_HEAD_LEATHER_SET3@4,T5_HEAD_LEATHER_MORGANA@4,T5_HEAD_LEATHER_HELL@4,T5_HEAD_LEATHER_UNDEAD@4,T5_HEAD_LEATHER_FEY@4,T5_HEAD_LEATHER_AVALON@4,,T6_HEAD_LEATHER_SET1,T6_HEAD_LEATHER_SET2,T6_HEAD_LEATHER_SET3,T6_HEAD_LEATHER_MORGANA,T6_HEAD_LEATHER_HELL,T6_HEAD_LEATHER_UNDEAD,T6_HEAD_LEATHER_FEY,T6_HEAD_LEATHER_AVALON,,T6_HEAD_LEATHER_SET1@1,T6_HEAD_LEATHER_SET2@1,T6_HEAD_LEATHER_SET3@1,T6_HEAD_LEATHER_MORGANA@1,T6_HEAD_LEATHER_HELL@1,T6_HEAD_LEATHER_UNDEAD@1,T6_HEAD_LEATHER_FEY@1,T6_HEAD_LEATHER_AVALON@1,?locations=5003,3005&qualities=2"


    render json: [url1, url2].to_json
  end

  def location_to_city(location)
    # def a better way to do this, just wanted it done for now
    case location
    when 4 then "SwampCross"
    when 7 then "Thetford"
    when 301 then "ThetfordPortal"
    when 8 then "MorganasRest"
    when 1002 then "Lymhurst"
    when 1301 then "LymhurstPortal"
    when 1006 then "ForestCross"
    when 1012 then "MerlynsRest"
    when 2002 then "SteppeCross"
    when 2004 then "Bridgewatch"
    when 2301 then "BridgewatchPortal"
    when 3002 then "HighlandCross"
    when 3003 then "BlackMarket"
    when 3005 then "Caerleon"
    when 3008 then "Martlock"
    when 3301 then "MartlockPortal"
    when 3013 then "Caerleon2"
    when 4002 then "FortSterling"
    when 4301 then "FortSterlingPortal"
    when 4006 then "MountainCross"
    when 4300 then "ArthursRest"
    when 5003 then "Brecilien"
    else location
    end
  end

  def city_to_location(city)
    # def a better way to do this, just wanted it done for now
    case city
    when "SwampCross" then 4
    when "Thetford" then 7
    when "ThetfordPortal" then 301
    when "MorganasRest" then 8
    when "Lymhurst" then 1002
    when "LymhurstPortal" then 1301
    when "ForestCross" then 1006
    when "MerlynsRest" then 1012
    when "SteppeCross" then 2002
    when "Bridgewatch" then 2004
    when "BridgewatchPortal" then 2301
    when "HighlandCross" then 3002
    when "BlackMarket" then 3003
    when "Caerleon" then 3005
    when "Martlock" then 3008
    when "MartlockPortal" then 3301
    when "Caerleon2" then 3013
    when "FortSterling" then 4002
    when "FortSterlingPortal" then 4301
    when "MountainCross" then 4006
    when "ArthursRest" then 4300
    when "Brecilien" then 5003
    else city.to_i
    end
  end

  def get_locations(params)
    # parse any city name strings to location ids
    locations = params[:locations].split(',').each.map{|l| city_to_location(l) } if params.key?(:locations)

    # set default locations to search, if none are sent in the query string
    locations = [3005,5003].each.map{|l| l.to_i } if locations.nil?

    # now map all locations to city names, for result array/hash sorting purposes
    locations = locations.each.map{|l| location_to_city(l)}

    locations
  end

  def get_qualities(params)
      # parse any qualitiles
      qualities = params[:qualities].split(',').each.map{|q| q.to_i} if params.key?(:qualities)

      # set default qualities, if none are sent in the query string
      qualities = [1,2,3,4,5] if qualities.nil?

      qualities
  end

  def prepare_emtpy_results(ids, locations, qualities)
    results = {}

    ids.sort.each do |id|
      locations.each do |location|
        qualities.each do |quality|
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

    last_groups = {}
    orders = MarketOrder.where(item_id: ids, updated_at: 1.days.ago..)
    orders = orders.where(location: locations.each.map{|c| city_to_location(c)})
    orders = orders.where(quality_level: qualities)
    orders = orders.select(:item_id, :location, :auction_type, :quality_level, :price, :updated_at)

    orders.each do |order|

      o_key = "#{order[:item_id]}_#{location_to_city(order[:location])}_#{order[:quality_level]}"

      # determine group block
      dt = order[:updated_at]
      this_group = DateTime.new(dt.year, dt.month, dt.day, dt.hour, dt.to_datetime.minute - (dt.to_datetime.minute % 5), 0).strftime('%Y-%m-%dT%H:%M:%S')
      last_groups[o_key] = DateTime.new(0001, 1, 1, 0, 0, 0) unless last_groups.key?(o_key)

      # more recent time group block?
      if this_group > last_groups[o_key]
        last_groups[o_key] = this_group

        if order[:auction_type] == 'offer'
          results[o_key].merge!({sell_price_min: 999999999999, sell_price_min_date: nil, sell_price_max: 0, sell_price_max_date: nil })
        elsif order[:auction_type] == 'request'
          results[o_key].merge!({buy_price_min: 999999999999, buy_price_min_date: nil, buy_price_max: 0, buy_price_max_date: nil })
        end
      end

      if order[:auction_type] == 'offer'
        # sell
        results[o_key].merge!({sell_price_min: order[:price], sell_price_min_date: this_group}) if order[:price] < results[o_key][:sell_price_min]
        results[o_key].merge!({sell_price_max: order[:price], sell_price_max_date: this_group}) if order[:price] > results[o_key][:sell_price_max]

      elsif order[:auction_type] == 'request'
        # buy
        results[o_key].merge!({buy_price_min: order[:price], buy_price_min_date: this_group}) if order[:price] < results[o_key][:buy_price_min]
        results[o_key].merge!({buy_price_max: order[:price], buy_price_max_date: this_group}) if order[:price] > results[o_key][:buy_price_max]
      end

    end

    sorted_results = []
    default_date = DateTime.new(0001, 1, 1, 0, 0, 0).strftime('%Y-%m-%dT%H:%M:%S')
    results.keys.sort.each do |key|

      result = results[key]
      result.merge!({ sell_price_min_date: default_date, sell_price_min: 0 }) if result[:sell_price_min_date].nil?
      result.merge!({ sell_price_max_date: default_date, sell_price_max: 0 }) if result[:sell_price_max_date].nil?
      result.merge!({ buy_price_min_date: default_date, buy_price_min: 0 }) if result[:buy_price_min_date].nil?
      result.merge!({ buy_price_max_date: default_date, buy_price_max: 0 }) if result[:buy_price_max_date].nil?

      sorted_results << result
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
