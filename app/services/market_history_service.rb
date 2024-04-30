class MarketHistoryService

  CITY_TO_LOCATION = {
    "swampcross": 4,
    "thetford": 7,
    "thetfordportal": 9,
    "morganasrest": 8,
    "lymhurst": 1002,
    "lymhurstportal": 1301,
    "forestcross": 1006,
    "merlynsrest": 1012,
    "steppecross": 2002,
    "bridgewatch": 2004,
    "bridgewatchportal": 2301,
    "highlandcross": 3002,
    "BlackMarket": 3003,
    "Blackmarket": 3003,
    "blackmarket": 3003,
    "Black Market": 3003,
    "caerleon2": 3005,
    "caerleon": 3005,
    "martlock": 3008,
    "martlockportal": 3301,
    "fortsterling": 4002,
    "fortsterlingportal": 4301,
    "mountaincross": 4006,
    "arthursrest": 4300,
    "brecilien": 5003,
  }

  LOCATION_TO_CITY = CITY_TO_LOCATION.invert.transform_keys(&:to_s)

  def location_to_city(location)
    LOCATION_TO_CITY[location.to_s] || location.to_s.to_sym
  end

  def city_to_location(city)
    CITY_TO_LOCATION[city.to_sym] || city.to_i
  end

  def get_locations(params)
    default_locations = [4, 7, 301, 8, 1002, 1301, 1006, 1012, 2002, 2004, 3002, 3003, 3005, 3008, 4002, 4006, 4300, 5003]
    locations = params[:locations]

    # locations = nil if params[:query_string].include?('locations[]')
    locations = locations&.map { |l| city_to_location(l.gsub(' ', '').downcase) }if locations.is_a?(Array)

    locations = default_locations if locations.nil?
    locations = default_locations if locations == 0 || locations == '0'
    locations = locations&.split(',')&.map { |l| city_to_location(l.gsub(' ', '').downcase) } if locations.is_a?(String)
    locations
  end

  SPLIT_WORDS = ['swamp', 'portal', 'cross', 'market', 'sterling', 'rest']

  def humanize_city(city)
    SPLIT_WORDS.each { |w| city = city.to_s.gsub(w, "_#{w}").titleize}
    city
  end

  def get_qualities(params)
    qualities = params[:qualities]

    # qualities = nil if params[:query_string].include?('qualities[]')
    qualities = qualities.map(&:to_i) if qualities.is_a?(Array) && qualities[0].is_a?(String)

    qualities = [1] if qualities.nil?
    qualities = [1,2,3,4,5] if qualities == 0 || qualities == '0'
    qualities = qualities.split(',').map(&:to_i) if qualities.is_a?(String)

    qualities
  end

  def get_stats(params)
    ids, locations, qualities = params[:id].upcase.split(','), get_locations(params), get_qualities(params)
    timescale = params[:'time-scale']&.to_i.in?([1,6,24]) ? params[:'time-scale'].to_i : 1

    date_start = if params[:date] && !params[:date].empty?
                 DateTime.parse(params[:date]) rescue DateTime.strptime(params[:date], "%m-%d-%Y")
               else
                 30.days.ago
               end

    date_end = if params[:end_date] && !params[:end_date].empty?
                 DateTime.parse(params[:end_date]) rescue DateTime.strptime(params[:end_date], "%m-%d-%Y")
               else
                 date_start + 30.days
               end


    histories = {}

    # build a hash of humanized cities for this call
    humanized_cities = {}
    locations.each do |location|
      humanized_cities[location] = humanize_city(location_to_city(location).to_s)
    end

    # create empty results that are presorted by item_id, city string, and quality
    cities = locations.map { |location| humanized_cities[location] }
    cities.sort.product(ids.sort, qualities.sort).each do |city, id, quality|
      key = "#{city}!!#{id}!!#{quality}"
      histories[key] = { location: city, item_id: id, quality: quality, data: {} }
    end

    data = []
    execution_time = Benchmark.measure do
      data = MarketHistory.where(item_id: ids, location: locations, quality: qualities, aggregation: (timescale == 24 ? 6 : timescale))
                          .where('timestamp >= ? and timestamp <= ?', date_start, date_end)
                          .order('item_id, location, quality, timestamp')
    end
    Rails.logger.info("Retriving data took #{execution_time.real} seconds")

    # mixin data from query
    execution_time = Benchmark.measure do
      counter = 0
      data.each do |history|
        counter += 1
        city = humanized_cities[history.location]
        key = "#{city}!!#{history.item_id}!!#{history.quality}"
        # histories[key] ||= { location: city, item_id: history.item_id, quality: history.quality, data: {} }

        if timescale == 24
          # "Adjust timestamp back 1 minute since the 00:00:00 timestamp should be included as end of day, not beginning"
          # ^ Taken from comments from the original code, I do not agree with this, but I want to keep the original behavior - phendryx/stanx
          timestamp = history.timestamp - 1.minute
          timestamp_date = timestamp.strftime('%Y-%m-%d')
          timestamp_timescale = (timestamp.hour / timescale).floor
          timeblock = "#{timestamp_date}-#{timestamp_timescale}"
          timestamp = DateTime.parse("#{timestamp_date} #{timestamp_timescale * 6}:00:00").strftime('%Y-%m-%dT%H:%M:%S')
        else

          timestamp = history.timestamp
          timestamp_date = timestamp.strftime('%Y-%m-%d')
          timestamp_timescale = (timestamp.hour / timescale).floor
          timeblock = "#{timestamp_date}-#{timestamp_timescale}"
          timestamp = timestamp.strftime('%Y-%m-%dT%H:%M:%S')
        end

        histories[key][:data][timeblock] ||= { item_count: 0, avg_price: 0, timestamp: timestamp, sum_silver: 0 }
        histories[key][:data][timeblock][:item_count] += history.item_amount
        histories[key][:data][timeblock][:sum_silver] += history.silver_amount
      end
      Rails.logger.info("Counter: #{counter}")
    end
    Rails.logger.info("Data processing took #{execution_time.real} seconds")

    # calculate avg price and remove empty data
    execution_time = Benchmark.measure do
      histories.each_value do |v|
        key = "#{v[:location]}!!#{v[:item_id]}!!#{v[:quality]}"
        v[:data].each_value { |data| data[:avg_price] = data[:sum_silver] / data[:item_count] }
        v[:data] = v[:data].values.map { |d| d.except(:sum_silver) }
        # v[:location] = humanized_cities[v[:location]]
        # histories[key][:location] = humanize_city(v[:location])
        histories.delete(key) if v[:data].empty?
      end
    end
    Rails.logger.info("Data calculation took #{execution_time.real} seconds")

    histories.values
  end

  def get_charts(params)
    params[:qualities] = [1,2,3,4,5] if params[:qualities].nil?
    params[:'time-scale'] = 6 if params[:'time-scale'].nil?

    history = get_stats(params)
    charts = {}
    history.each do |h|
      key = "#{h[:location]}-#{h[:item_id]}-#{h[:quality]}"
      charts[key] ||= { location: h[:location], item_id: h[:item_id], quality: h[:quality], data: { timestamps: [], prices_avg: [], item_count: [] } }
      h[:data].each do |d|
        charts[key][:data][:timestamps] << d[:timestamp]
        charts[key][:data][:prices_avg] << d[:avg_price]
        charts[key][:data][:item_count] << d[:item_count]
      end
    end

    charts.values
  end
end