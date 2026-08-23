class StatsAPI < Grape::API
  XmlPayload = Struct.new(:kind, :data)

  format :json
  content_type :xml, 'application/xml'
  content_type :html, 'text/html'

  formatter :xml, lambda { |object, _env|
    case object
    when XmlPayload
      case object.kind
      when :gold then Stats::GoldXmlSerializer.call(object.data)
      when :prices then Stats::PricesXmlSerializer.call(object.data)
      when :history then Stats::HistoryXmlSerializer.call(object.data)
      when :charts then Stats::ChartsXmlSerializer.call(object.data)
      end
    else
      object.to_s
    end
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
    end
    get 'prices/:id' do
      with_database do
        Rails.logger.info("multidb_info: server_id: #{server_id}, database: #{Multidb.balancer.current_connection.raw_connection.connection_options[:database]}")
        sorted_results = MarketDataService.new.get_stats(params.merge(query_string: request.query_string))

        env['api.format'] == :xml ? XmlPayload.new(:prices, sorted_results) : sorted_results
      end
    end

    desc 'Get current market prices for an item as an HTML table'
    params do
      requires :id, type: String, desc: 'Comma-separated list of item IDs, e.g. T4_BAG'
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
    end
    get 'charts/:id' do
      with_database do
        results = MarketHistoryService.new.get_charts(params.merge(query_string: request.query_string))

        env['api.format'] == :xml ? XmlPayload.new(:charts, results) : results
      end
    end
  end

  add_swagger_documentation
end
