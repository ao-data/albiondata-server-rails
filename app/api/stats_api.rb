class StatsAPI < Grape::API
  XmlPayload = Struct.new(:kind, :data)

  content_type :json, 'application/json; charset=utf-8'
  format :json
  content_type :xml, 'application/xml; charset=utf-8'
  content_type :html, 'text/html'

  formatter :xml, lambda { |object, _env|
    case object
    when XmlPayload
      case object.kind
      when :gold then Stats::GoldXmlSerializer.call(object.data)
      when :prices then Stats::PricesXmlSerializer.call(object.data)
      when :orderbook then Stats::OrderbookXmlSerializer.call(object.data)
      when :history then Stats::HistoryXmlSerializer.call(object.data)
      when :charts then Stats::ChartsXmlSerializer.call(object.data)
      end
    else
      object.to_s
    end
  }

  formatter :html, lambda { |object, env|
    object.is_a?(String) ? object : Grape::Formatter::Json.call(object, env)
  }

  helpers do
    def server_id
      ActionDispatch::Http::URL.extract_subdomains(request.host, 1).last
    end

    def with_database(&block)
      subdomain = ActionDispatch::Http::URL.extract_subdomains(request.host, 1).join('.')
      Rails.logger.info("using database #{subdomain}")
      Multidb.use(server_id, &block)
    end
  end

  prefix 'api'
  version 'v2', using: :path

  rescue_from Grape::Exceptions::Base do |e|
    error!({ error: e.message }, e.status || 500)
  end

  rescue_from StandardError do |e|
    env['api.format'] = :json
    Rails.logger.error({ location: "StatsAPI #{request.request_method} #{request.path}", message: e.message, backtrace: e.backtrace, params: params, query_string: request.query_string })
    error!({ error: 'Internal Server Error' }, 500)
  end

  namespace 'stats' do
    desc 'List gold prices for a date range'
    params do
      optional :date, type: String, desc: 'Start date, format MM-DD-YYYY. Defaults to one month ago.'
      optional :end_date, type: String, desc: 'End date, format MM-DD-YYYY. Defaults to now.'
      optional :count, type: String, desc: 'Limit results to this many, ordered most-recent-first.'
    end
    get 'gold' do
      with_database do
        date_from = params.key?(:date) ? Date.strptime(params[:date], '%m-%d-%Y') : DateTime.now - 1.month
        date_to = (params.key?(:end_date) ? Date.strptime(params[:end_date], '%m-%d-%Y') : DateTime.now) + 1.day

        Rails.logger.info("multidb_info: server_id: #{server_id}, database: #{Multidb.balancer.current_connection.raw_connection.connection_options[:database]}")
        relation = GoldPrice.where(timestamp: date_from..date_to)
        relation = relation.order(timestamp: :desc).limit(params[:count].to_i) if params.key?(:count)

        results = relation.map do |row|
          entry = { price: row[:price] / 10000, timestamp: row[:timestamp].strftime('%Y-%m-%dT%H:%M:%S') }
          entry[:id] = row[:id] if env['api.format'] == :xml
          entry
        end

        env['api.format'] == :xml ? XmlPayload.new(:gold, results) : results
      end
    end

    desc 'Get current market prices for an item'
    params do
      requires :id, type: String, desc: 'Comma-separated list of item IDs, e.g. T4_BAG'
      optional :locations, types: [String, Array[String]], desc: 'Comma-separated list of locations/cities to filter by'
      optional :qualities, types: [String, Array[String]], desc: 'Comma-separated list of quality levels (1-5) to filter by'
    end
    get 'prices/:id' do
      with_database do
        Rails.logger.info("multidb_info: server_id: #{server_id}, database: #{Multidb.balancer.current_connection.raw_connection.connection_options[:database]}")
        sorted_results = MarketDataService.new.get_stats(params.merge(query_string: request.query_string))

        env['api.format'] == :xml ? XmlPayload.new(:prices, sorted_results) : sorted_results
      end
    end

    desc 'Get the live order book (price levels and depth) for an item'
    params do
      requires :id, type: String, desc: 'Comma-separated list of item IDs, e.g. T4_BAG'
      optional :locations, types: [String, Array[String]], desc: 'Comma-separated list of locations/cities to filter by'
      optional :qualities, types: [String, Array[String]], desc: 'Comma-separated list of quality levels (1-5) to filter by'
    end
    get 'orderbook/:id' do
      with_database do
        Rails.logger.info("multidb_info: server_id: #{server_id}, database: #{Multidb.balancer.current_connection.raw_connection.connection_options[:database]}")
        sorted_results = MarketOrderbookService.new.get_orderbook(params.merge(query_string: request.query_string))

        env['api.format'] == :xml ? XmlPayload.new(:orderbook, sorted_results) : sorted_results
      end
    end

    desc 'Get current market prices for an item as an HTML table'
    params do
      requires :id, type: String, desc: 'Comma-separated list of item IDs, e.g. T4_BAG'
      optional :locations, types: [String, Array[String]], desc: 'Comma-separated list of locations/cities to filter by'
      optional :qualities, types: [String, Array[String]], desc: 'Comma-separated list of quality levels (1-5) to filter by'
    end
    get 'view/:id' do
      with_database do
        sorted_results = MarketDataService.new.get_stats(params.merge(query_string: request.query_string))
        env['api.format'] = :html
        content_type 'text/html; charset=utf-8'
        body Stats::PricesHtmlTableSerializer.call(sorted_results)
      end
    end

    desc 'Get historical market prices for an item'
    params do
      requires :id, type: String, desc: 'Comma-separated list of item IDs, e.g. T4_BAG'
      optional :locations, types: [String, Array[String]], desc: 'Comma-separated list of locations/cities to filter by'
      optional :qualities, types: [String, Array[String]], desc: 'Comma-separated list of quality levels (1-5) to filter by'
      optional :date, type: String, desc: 'Start date, format MM-DD-YYYY or YYYY-MM-DD'
      optional :end_date, type: String, desc: 'End date, format MM-DD-YYYY or YYYY-MM-DD'
      optional :'time-scale', type: String, desc: 'Aggregation timescale in hours: 1, 6, or 24'
    end
    get 'history/:id' do
      with_database do
        Rails.logger.info("multidb_info: server_id: #{server_id}, database: #{Multidb.balancer.current_connection.raw_connection.connection_options[:database]}")
        results = MarketHistoryService.new.get_stats(params.merge(query_string: request.query_string))

        env['api.format'] == :xml ? XmlPayload.new(:history, results) : results
      end
    end

    desc 'Get historical market price chart data for an item'
    params do
      requires :id, type: String, desc: 'Comma-separated list of item IDs, e.g. T4_BAG'
      optional :locations, types: [String, Array[String]], desc: 'Comma-separated list of locations/cities to filter by'
      optional :qualities, types: [String, Array[String]], desc: 'Comma-separated list of quality levels (1-5) to filter by'
      optional :date, type: String, desc: 'Start date, format MM-DD-YYYY or YYYY-MM-DD'
      optional :end_date, type: String, desc: 'End date, format MM-DD-YYYY or YYYY-MM-DD'
      optional :'time-scale', type: String, desc: 'Aggregation timescale in hours: 1, 6, or 24'
    end
    get 'charts/:id' do
      with_database do
        results = MarketHistoryService.new.get_charts(params.merge(query_string: request.query_string))

        env['api.format'] == :xml ? XmlPayload.new(:charts, results) : results
      end
    end

    desc 'Get the latest confirmed festivities snapshot for the current server'
    get 'festivities' do
      with_database do
        env['api.format'] = :json
        snapshot = REDIS[server_id].get(FestivitiesService::CURRENT_SNAPSHOT_KEY)
        error!({ error: 'No confirmed festivities snapshot' }, 404) if snapshot.nil?

        header 'Cache-Control', 'public, max-age=60, stale-while-revalidate=300'
        JSON.parse(snapshot)
      end
    end

    desc 'Get identifier events recorded for the current server'
    params do
      requires :identifier, type: String, desc: 'Client-generated identifier to look up events for'
    end
    get 'identifier/:identifier' do
      with_database do
        env['api.format'] = :json
        error!({ error: 'Identifier is required' }, 400) if params[:identifier].nil? || params[:identifier].empty?

        IdentifierService.get_identifier_events(params[:identifier], server_id)
      end
    end
  end

  add_swagger_documentation info: { title: 'Albion Online Data Project API', description: 'Market price, history, gold, festivities, and identifier stats for Albion Online.' }
end
