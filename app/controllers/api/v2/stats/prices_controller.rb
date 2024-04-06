class API::V2::Stats::PricesController < API::V2::APIController
  def show
    begin
      sorted_results = MarketDataService.new.get_stats(params.merge({ query_string: request.query_string}))

      respond_to do |format|
        format.xml { render xml: show_xml(sorted_results) }
        format.json { render json: sorted_results }
      end
    rescue StandardError => e
      logger.error({location: 'API::V2::Stats::PricesController.show', message: e.message, backtrace: e.backtrace, params: params, query_string: request.query_string})
      render json: { error: 'Internal Server Error' }, status: :internal_server_error
    end
  end

  def show_xml(sorted_results)
    xml_results = Nokogiri::XML::Builder.new do |xml|
      xml.ArrayOfMarketResponse('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema') {
        sorted_results.each do |r|
          xml.MarketResponse {
            xml.ItemTypeId r[:item_id]
            xml.City r[:city]
            xml.QualityLevel r[:quality]
            xml.SellPriceMin r[:sell_price_min]
            xml.SellPriceMinDate r[:sell_price_min_date]
            xml.SellPriceMax r[:sell_price_max]
            xml.SellPriceMaxDate r[:sell_price_max_date]
            xml.BuyPriceMin r[:buy_price_min]
            xml.BuyPriceMinDate r[:buy_price_min_date]
            xml.BuyPriceMax r[:buy_price_max]
            xml.BuyPriceMaxDate r[:buy_price_max_date]
          }
        end
      }
    end

    xml_results.to_xml
  end

  def show_table
    sorted_results = MarketDataService.new.get_stats(params)

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



end
