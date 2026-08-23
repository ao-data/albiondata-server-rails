module Stats
  class HistoryXmlSerializer
    def self.call(results)
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
end
