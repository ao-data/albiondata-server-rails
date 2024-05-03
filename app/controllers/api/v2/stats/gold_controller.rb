class API::V2::Stats::GoldController < API::V2::APIController

  def index
    begin
      date_from = params.key?(:date) ? Date.strptime(params[:date], '%m-%d-%Y') : DateTime.now - 1.month
      date_to = (params.key?(:end_date) ? Date.strptime(params[:end_date], '%m-%d-%Y') : DateTime.now) + 1.day

      results = GoldPrice.where(timestamp: date_from..date_to).order(timestamp: :asc).map do |row|
        data = { price: row[:price] / 10000, timestamp: row[:timestamp].strftime('%Y-%m-%dT%H:%M:%S') }
        data.merge!({ id: row[:id] }) if request.format == :xml
        data
      end

      respond_to do |format|
        format.xml { render xml: show_xml(results) }
        format.json { render json: results }
      end
    rescue StandardError => e
      logger.error({location: 'API::V2::Stats::GoldController.index', message: e.message, backtrace: e.backtrace, params: params, query_string: request.query_string})
      render json: { error: 'Internal Server Error' }, status: :internal_server_error
    end
  end

  def show_xml(results)
    xml_results = Nokogiri::XML::Builder.new do |xml|
      xml.ArrayOfGoldPrice('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema') {
        results.each do |r|
          xml.GoldPrice {
            xml.Id r[:id]
            xml.Price r[:price]
            xml.Timestamp r[:timestamp]
          }
        end
      }
    end

    xml_results.to_xml
  end
end

