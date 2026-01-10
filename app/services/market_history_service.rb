class MarketHistoryService
  # called by api controller, which sets which database to use

  include Location
  include Quality

  def get_stats(params)
    ids, locations, qualities = params[:id].upcase.split(','), get_locations(params), get_qualities(params)
    timescale = params[:'time-scale']&.to_i.in?([1,6,24]) ? params[:'time-scale'].to_i : 1

    date_start = if params[:date] && !params[:date].empty?
                 begin
                   DateTime.strptime(params[:date], "%m-%d-%Y")
                 rescue ArgumentError
                   DateTime.strptime(params[:date], "%Y-%m-%d")
                 end
               else
                 30.days.ago
               end

    date_end = if params[:end_date] && !params[:end_date].empty?
                 begin
                   DateTime.strptime(params[:end_date], "%m-%d-%Y")
                 rescue ArgumentError
                   DateTime.strptime(params[:end_date], "%Y-%m-%d")
                 end
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
                          .select(:item_id, :location, :quality, :timestamp, :item_amount, :silver_amount)

      rows = MarketOrder.connection.select_rows(data.to_sql)
      data = rows
    end
    Rails.logger.info("Retriving data took #{execution_time.real} seconds")

    # mixin data from query
    execution_time = Benchmark.measure do
      counter = 0
      data.each do |r|
        h_item_id, h_location, h_quality, h_timestamp, h_item_amount, h_silver_amount = r

        counter += 1
        city = humanized_cities[h_location]
        key = "#{city}!!#{h_item_id}!!#{h_quality}"

        if timescale == 24
          # "Adjust timestamp back 1 minute since the 00:00:00 timestamp should be included as end of day, not beginning"
          # ^ Taken from comments from the original code, I do not agree with this, but I want to keep the original behavior - phendryx/stanx
          timestamp = h_timestamp - 1.minute
          timestamp_date = timestamp.strftime('%Y-%m-%d')
          timeblock = "#{timestamp_date}-0"
          timestamp = "#{timestamp_date}T00:00:00"
        else

          timestamp = h_timestamp
          timestamp_date = timestamp.strftime('%Y-%m-%d')
          timestamp_timescale = (timestamp.hour / timescale).floor
          timeblock = "#{timestamp_date}-#{timestamp_timescale}"
          timestamp = timestamp.strftime('%Y-%m-%dT%H:%M:%S')
        end

        histories[key][:data][timeblock] ||= { item_count: 0, avg_price: 0, timestamp: timestamp, sum_silver: 0 }
        histories[key][:data][timeblock][:item_count] += h_item_amount
        histories[key][:data][timeblock][:sum_silver] += h_silver_amount
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
