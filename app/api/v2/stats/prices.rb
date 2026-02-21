module API
  module V2
    module Stats
      class Prices < Grape::API
        format :json
        default_format :json
        formatter :xml, ->(object, _env) { xml_formatter(object) }
        formatter :html, ->(object, _env) { object }

        helpers do
          def market_data_service
            ::MarketDataService.new
          end

          def sorted_results(params)
            market_data_service.get_stats(params)
          end

          def xml_formatter(sorted_results)
            Nokogiri::XML::Builder.new do |xml|
              xml.ArrayOfMarketResponse('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                                        'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema') do
                sorted_results.each do |r|
                  xml.MarketResponse do
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
                  end
                end
              end
            end.to_xml
          end

          def html_table(sorted_results)
            fields = %i[item_id city quality sell_price_min sell_price_min_date sell_price_max
                        sell_price_max_date buy_price_min buy_price_min_date buy_price_max buy_price_max_date]
            rows = []
            rows << '<head><style>table, th, td {border: 1px solid black;border-collapse: collapse;}</style></head><body>'
            rows << "<table style='width:100%'>"
            rows << '<tr>'
            fields.each { |f| rows << "<th>#{f}</th>" }
            rows << '</tr>'
            default_date = DateTime.new(1, 1, 1, 0, 0, 0).strftime('%Y-%m-%dT%H:%M:%S')
            sorted_results.each do |r|
              row = []
              row << '<tr>'
              fields.each do |f|
                row << (r[f] == 0 || r[f] == default_date ? '<td></td>' : "<td>#{r[f]}</td>")
              end
              row << '</tr>'
              rows << row.join('')
            end
            rows << '</table></body>'
            rows.join('')
          end
        end

        resource :prices do
          desc 'Get market stats (JSON or XML)'
          get do
            begin
              results = sorted_results(params)
              case env['api.format']
              when :xml
                present results, with: Prices, format: :xml
              else
                results
              end
            rescue StandardError => e
              error!({ error: 'Internal Server Error', message: e.message }, 500)
            end
          end

          desc 'Get market stats as HTML table'
          get :table do
            begin
              results = sorted_results(params)
              html = html_table(results)
              env['api.format'] = :html
              present html
            rescue StandardError => e
              error!({ error: 'Internal Server Error', message: e.message }, 500)
            end
          end
        end
      end
    end
  end
end