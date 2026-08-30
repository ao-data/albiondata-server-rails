class MarketOrderbookService
  include Location
  include Quality

  def get_orderbook(params)
    ids, locations, qualities = params[:id].upcase.split(',').map(&:strip).uniq, get_locations(params), get_qualities(params)

    humanized_cities = {}
    locations.each do |location|
      humanized_cities[location] = humanize_city(location_to_city(location).to_s)
    end

    data = MarketOrder
      .where(item_id: ids, deleted_at: nil)
      .where('expires > ?', Time.now)
      .where('price > 0')
      .where('amount > 0')
    data = data.where(location: locations) unless locations.empty?
    data = data.where(quality_level: qualities) unless qualities.empty?
    data = data
      .group(:item_id, :location, :quality_level, :auction_type, :price)
      .select(:item_id, :location, :quality_level, :auction_type, :price,
              'SUM(market_orders.amount) AS total_amount',
              "DATE_FORMAT(MAX(market_orders.updated_at), '%Y-%m-%dT%H:%i:%s') AS updated_at")

    rows = []
    execution_time = Benchmark.measure do
      rows = MarketOrder.connection.select_rows(data.to_sql)
    end
    Rails.logger.info("Retrieving order book took #{execution_time.real} seconds")

    books = {}
    rows.each do |item_id, location, quality_level, auction_type, price, total_amount, updated_at|
      city = humanized_cities[location.to_i] || humanize_city(location_to_city(location.to_i).to_s)
      key = "#{item_id}!!#{city}!!#{quality_level}"

      books[key] ||= { item_id: item_id, city: city, quality: quality_level, sell: [], buy: [] }
      level = { price: price.to_i, amount: total_amount.to_i, updated_at: updated_at }

      if auction_type == 'offer'
        books[key][:sell] << level
      else
        books[key][:buy] << level
      end
    end

    default_values = { sell: [], buy: [] }
    humanized_location_strings = locations.map { |location| humanized_cities[location] }
    ids.sort.product(humanized_location_strings.sort, qualities.sort).each do |item_id, city, quality|
      key = "#{item_id}!!#{city}!!#{quality}"
      books[key] ||= { item_id: item_id, city: city, quality: quality }.merge(default_values)
    end

    books.values_at(*books.keys.sort).map do |book|
      book[:sell].sort_by! { |level| level[:price] }
      book[:buy].sort_by! { |level| -level[:price] }
      book
    end
  end
end
