module Stats
  class OrderbookXmlSerializer
    def self.call(sorted_results)
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
end
