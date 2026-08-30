class API::V2::Stats::OrderbookController < API::V2::APIController
  def show
    begin
      logger.info("multidb_info: server_id: #{server_id}, database: #{Multidb.balancer.current_connection.raw_connection.connection_options[:database]}")
      sorted_results = MarketOrderbookService.new.get_orderbook(params.merge({ query_string: request.query_string }))

      respond_to do |format|
        format.xml { render xml: show_xml(sorted_results) }
        format.json { render json: sorted_results }
      end
    rescue StandardError => e
      logger.error({location: 'API::V2::Stats::OrderbookController.show', message: e.message, backtrace: e.backtrace, params: params, query_string: request.query_string})
      render json: { error: 'Internal Server Error' }, status: :internal_server_error
    end
  end

  def show_xml(sorted_results)
    xml_results = Nokogiri::XML::Builder.new do |xml|
      xml.ArrayOfOrderbookResponse('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema') {
        sorted_results.each do |r|
          xml.OrderbookResponse {
            xml.ItemTypeId r[:item_id]
            xml.City r[:city]
            xml.QualityLevel r[:quality]
            xml.Sell {
              r[:sell].each do |level|
                xml.OrderLevel {
                  xml.Price level[:price]
                  xml.Amount level[:amount]
                  xml.UpdatedAt level[:updated_at]
                }
              end
            }
            xml.Buy {
              r[:buy].each do |level|
                xml.OrderLevel {
                  xml.Price level[:price]
                  xml.Amount level[:amount]
                  xml.UpdatedAt level[:updated_at]
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
