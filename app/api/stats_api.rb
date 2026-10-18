class StatsAPI < Grape::API
  XmlPayload = Struct.new(:kind, :data)
  JSON_OR_XML = ['application/json', 'application/xml'].freeze

  # Doc example rendered relative to the request: grape-swagger rebuilds swagger_doc per request but copies param
  # examples through as-is, so the date is only formatted when the doc is serialized to JSON.
  RelativeDateExample = Struct.new(:days_ago, :format) do
    def as_json(*) = (Date.current - days_ago).strftime(format)
    def to_s = as_json
  end

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

    # Same formats MarketHistoryService accepts for history/charts.
    def parse_date(value)
      Date.strptime(value, '%m-%d-%Y')
    rescue ArgumentError
      Date.strptime(value, '%Y-%m-%d')
    end

    # Documentation only: the format is picked from the .xml extension or ?format= (Accept is ignored), and
    # a real `values:` validator would start rejecting formats like .html that are accepted today.
    params :response_format do
      optional :format, type: String, desc: 'Response format; a .xml path extension works too',
                        documentation: { values: %w[json xml], default: 'json', param_type: 'query' }
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
    desc 'List gold prices for a date range', produces: JSON_OR_XML
    params do
      optional :date, type: String, desc: 'Start date. Supported formats: YYYY-MM-DD (preferred) or MM-DD-YYYY. Defaults to one month ago.', documentation: { example: RelativeDateExample.new(7, '%Y-%m-%d') }
      optional :end_date, type: String, desc: 'End date. Supported formats: YYYY-MM-DD (preferred) or MM-DD-YYYY. Defaults to now.', documentation: { example: RelativeDateExample.new(0, '%Y-%m-%d') }
      optional :count, type: String, desc: 'Limit results to this many, ordered most-recent-first.', documentation: { example: '10' }
      use :response_format
    end
    get 'gold' do
      with_database do
        date_from = params.key?(:date) ? parse_date(params[:date]) : DateTime.now - 1.month
        date_to = (params.key?(:end_date) ? parse_date(params[:end_date]) : DateTime.now) + 1.day

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

    desc 'Get current market prices for an item', produces: JSON_OR_XML
    params do
      requires :id, type: String, desc: 'Comma-separated list of item IDs, e.g. T4_BAG', documentation: { example: 't4_bag,t5_bag' }
      optional :locations, types: [String, Array[String]], desc: 'Comma-separated list of locations/cities to filter by. Cities with multiple words, e.g. Fort Sterling, can be given as fortsterling, Fort Sterling, or URL-encoded (Fort%20Sterling).', documentation: { example: 'caerleon,bridgewatch' }
      optional :qualities, types: [String, Array[String]], desc: 'Comma-separated list of quality levels (1-5) to filter by', documentation: { example: '1,2,3,4,5' }
      use :response_format
    end
    get 'prices/:id' do
      with_database do
        Rails.logger.info("multidb_info: server_id: #{server_id}, database: #{Multidb.balancer.current_connection.raw_connection.connection_options[:database]}")
        sorted_results = MarketDataService.new.get_stats(params.merge(query_string: request.query_string))

        env['api.format'] == :xml ? XmlPayload.new(:prices, sorted_results) : sorted_results
      end
    end

    desc 'Get the live order book (price levels and depth) for an item', produces: JSON_OR_XML
    params do
      requires :id, type: String, desc: 'Comma-separated list of item IDs, e.g. T4_BAG', documentation: { example: 't4_bag,t5_bag' }
      optional :locations, types: [String, Array[String]], desc: 'Comma-separated list of locations/cities to filter by. Cities with multiple words, e.g. Fort Sterling, can be given as fortsterling, Fort Sterling, or URL-encoded (Fort%20Sterling).', documentation: { example: 'caerleon,bridgewatch' }
      optional :qualities, types: [String, Array[String]], desc: 'Comma-separated list of quality levels (1-5) to filter by', documentation: { example: '1,2,3,4,5' }
      use :response_format
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
      requires :id, type: String, desc: 'Comma-separated list of item IDs, e.g. T4_BAG', documentation: { example: 't4_bag,t5_bag' }
      optional :locations, types: [String, Array[String]], desc: 'Comma-separated list of locations/cities to filter by. Cities with multiple words, e.g. Fort Sterling, can be given as fortsterling, Fort Sterling, or URL-encoded (Fort%20Sterling).', documentation: { example: 'caerleon,bridgewatch' }
      optional :qualities, types: [String, Array[String]], desc: 'Comma-separated list of quality levels (1-5) to filter by', documentation: { example: '1,2,3,4,5' }
    end
    get 'view/:id' do
      with_database do
        sorted_results = MarketDataService.new.get_stats(params.merge(query_string: request.query_string))
        env['api.format'] = :html
        content_type 'text/html; charset=utf-8'
        body Stats::PricesHtmlTableSerializer.call(sorted_results)
      end
    end

    desc 'Get historical market prices for an item', produces: JSON_OR_XML
    params do
      requires :id, type: String, desc: 'Comma-separated list of item IDs, e.g. T4_BAG', documentation: { example: 't4_bag,t5_bag' }
      optional :locations, types: [String, Array[String]], desc: 'Comma-separated list of locations/cities to filter by. Cities with multiple words, e.g. Fort Sterling, can be given as fortsterling, Fort Sterling, or URL-encoded (Fort%20Sterling).', documentation: { example: 'caerleon,bridgewatch' }
      optional :qualities, types: [String, Array[String]], desc: 'Comma-separated list of quality levels (1-5) to filter by', documentation: { example: '1,2,3,4,5' }
      optional :date, type: String, desc: 'Start date. Supported formats: YYYY-MM-DD (preferred) or MM-DD-YYYY. Defaults to 30 days ago.', documentation: { example: RelativeDateExample.new(7, '%Y-%m-%d') }
      optional :end_date, type: String, desc: 'End date. Supported formats: YYYY-MM-DD (preferred) or MM-DD-YYYY. Defaults to 30 days after the start date.', documentation: { example: RelativeDateExample.new(0, '%Y-%m-%d') }
      optional :'time-scale', type: String, desc: 'Aggregation timescale in hours: 1, 6, or 24', documentation: { example: '24' }
      use :response_format
    end
    get 'history/:id' do
      with_database do
        Rails.logger.info("multidb_info: server_id: #{server_id}, database: #{Multidb.balancer.current_connection.raw_connection.connection_options[:database]}")
        results = MarketHistoryService.new.get_stats(params.merge(query_string: request.query_string))

        env['api.format'] == :xml ? XmlPayload.new(:history, results) : results
      end
    end

    desc 'Get historical market price chart data for an item', produces: JSON_OR_XML
    params do
      requires :id, type: String, desc: 'Comma-separated list of item IDs, e.g. T4_BAG', documentation: { example: 't4_bag,t5_bag' }
      optional :locations, types: [String, Array[String]], desc: 'Comma-separated list of locations/cities to filter by. Cities with multiple words, e.g. Fort Sterling, can be given as fortsterling, Fort Sterling, or URL-encoded (Fort%20Sterling).', documentation: { example: 'caerleon,bridgewatch' }
      optional :qualities, types: [String, Array[String]], desc: 'Comma-separated list of quality levels (1-5) to filter by', documentation: { example: '1,2,3,4,5' }
      optional :date, type: String, desc: 'Start date. Supported formats: YYYY-MM-DD (preferred) or MM-DD-YYYY. Defaults to 30 days ago.', documentation: { example: RelativeDateExample.new(7, '%Y-%m-%d') }
      optional :end_date, type: String, desc: 'End date. Supported formats: YYYY-MM-DD (preferred) or MM-DD-YYYY. Defaults to 30 days after the start date.', documentation: { example: RelativeDateExample.new(0, '%Y-%m-%d') }
      optional :'time-scale', type: String, desc: 'Aggregation timescale in hours: 1, 6, or 24', documentation: { example: '24' }
      use :response_format
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
      requires :identifier, type: String, desc: 'Client-generated identifier to look up events for', documentation: { example: '3f2b8c1e-7a4d-4e9b-9c1a-2d5e6f7a8b9c' }
    end
    get 'identifier/:identifier' do
      with_database do
        env['api.format'] = :json
        error!({ error: 'Identifier is required' }, 400) if params[:identifier].nil? || params[:identifier].empty?

        IdentifierService.get_identifier_events(params[:identifier], server_id)
      end
    end
  end

  # Shown at the top of the Swagger UI page. Swagger UI 2.x inserts it as HTML. Rate limits come from the same env vars
  # config/initializers/rack_attack.rb reads; the fallbacks are the values the API page has always listed.
  API_DESCRIPTION = <<~HTML.freeze
    <p>Market price, history, order book, gold, festivities, and identifier stats for Albion Online.</p>

    <h4>Hosts</h4>
    <p>Pick the host for the game server you want, then append an endpoint path below. This page queries the server it was opened on.</p>
    <ul>
      <li>Americas (West): <code>https://west.albion-online-data.com</code></li>
      <li>Asia (East): <code>https://east.albion-online-data.com</code></li>
      <li>Europe: <code>https://europe.albion-online-data.com</code></li>
    </ul>

    <h4>Item and location IDs</h4>
    <p>Item IDs are in <a href="https://github.com/ao-data/ao-bin-dumps/blob/master/formatted/items.txt" target="_blank" rel="noopener">items.txt</a> /
    <a href="https://github.com/ao-data/ao-bin-dumps/blob/master/formatted/items.json" target="_blank" rel="noopener">items.json</a>.
    Location IDs and names are in <a href="https://github.com/ao-data/ao-bin-dumps/blob/master/formatted/world.txt" target="_blank" rel="noopener">world.txt</a> /
    <a href="https://github.com/ao-data/ao-bin-dumps/blob/master/formatted/world.json" target="_blank" rel="noopener">world.json</a>.</p>

    <h4>Formats and dates</h4>
    <p>JSON is the default. For XML, add <code>.xml</code> to the path (e.g. <code>/api/v2/stats/prices/T4_BAG.xml</code>) or pass <code>format=xml</code>.
    Dates accept <code>YYYY-MM-DD</code> (preferred) or <code>MM-DD-YYYY</code>.</p>

    <h4>Rate limits</h4>
    <ul>
      <li>#{ENV.fetch('THROTTLE_API_1MIN', '180')} requests per minute and #{ENV.fetch('THROTTLE_API_5MIN', '300')} requests per 5 minutes, per IP.</li>
      <li><strong>Use compression.</strong> Requests that don't accept gzip, deflate, br, or zstd (via <code>Accept-Encoding</code>) are limited to 6 per minute.
      The curl, Python, Node, and Ruby snippets shown after "Try it out" already request compression.</li>
      <li>Throttled requests get HTTP <code>429</code> with <code>RateLimit-Limit</code>, <code>RateLimit-Remaining</code>, and <code>RateLimit-Reset</code> (epoch seconds) headers.</li>
    </ul>

    <h4>Getting a lot of data</h4>
    <p>Combine many items and locations in one request rather than making many small ones; just keep the URL under <strong>4096 characters</strong>.
    If you run a service that hits the API continually, compression keeps the project sustainable: server and bandwidth are not free.</p>

    <h4>Spreadsheets</h4>
    <ul>
      <li><strong>Excel:</strong> use Power Query to connect to the API URLs.</li>
      <li><strong>Google Sheets (XML):</strong> <a href="https://support.google.com/docs/answer/3093342?hl=en" target="_blank" rel="noopener">IMPORTXML</a>, e.g.
      <code>=IMPORTXML("https://west.albion-online-data.com/api/v2/stats/prices/T4_BAG.xml?locations=Caerleon&amp;qualities=2","//ArrayOfMarketResponse/MarketResponse")</code></li>
      <li><strong>Google Sheets (JSON):</strong> the third-party <a href="https://github.com/bradjasper/ImportJSON" target="_blank" rel="noopener">ImportJSON</a> script, e.g.
      <code>=ImportJSON("https://west.albion-online-data.com/api/v2/stats/prices/T4_BAG.json?locations=Caerleon&amp;qualities=2", "", "noHeaders")</code>
      (some people have seen repeating rows with it).</li>
    </ul>
  HTML

  add_swagger_documentation info: { title: 'Albion Online Data Project API', description: API_DESCRIPTION }
end
