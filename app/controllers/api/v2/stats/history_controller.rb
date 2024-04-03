class API::V2::Stats::HistoryController < API::V2::APIController

  def show
    begin
      results = MarketHistoryService.new.get_stats(params.merge({ query_string: request.query_string}))

      respond_to do |format|
        format.xml { render xml: show_xml(results) }
        format.json { render json: results.to_json }
      end
    rescue StandardError => e
      logger.error({location: 'API::V2::Stats::HistoryController.show', message: e.message, backtrace: e.backtrace, params: params, query_string: request.query_string})
      render json: { error: 'Internal Server Error' }, status: :internal_server_error
    end
  end

  def show_xml(results)
    xml_results = Nokogiri::XML::Builder.new do |xml|
      xml.ArrayOfMarketHistoriesResponse('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema') {
        results.each do |r|
          xml.MarketHistoriesResponse {
            xml.Location r[:location]
            xml.ItemTypeId r[:item_id]
            xml.QualityLevel r[:quality]
            xml.Data {
              r[:data].each do |d|
                xml.MarketHistoryResponse {
                  xml.ItemCount d[:item_count]
                  xml.AveragePrice d[:avg_price]
                  xml.Timestamp d[:timestamp]
                }
              end
            }
          }
        end
      }
    end


    xml_results.to_xml
  end
end
