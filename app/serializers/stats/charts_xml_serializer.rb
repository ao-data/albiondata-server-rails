module Stats
  class ChartsXmlSerializer
    def self.call(results)
      xml_results = Nokogiri::XML::Builder.new do |xml|
        xml.ArrayOfMarketStatChartResponsev2('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema') {
          results.each do |r|
            xml.MarketStatChartResponsev2 {
              xml.Location r[:location]
              xml.ItemTypeId r[:item_id]
              xml.QualityLevel r[:quality]
              xml.Data {
                xml.Timestamps {
                  r[:data][:timestamps].each do |t|
                    xml.dateTime t
                  end
                }
                xml.PricesAverage {
                  r[:data][:prices_avg].each do |pa|
                    xml.decimal pa
                  end
                }
                xml.ItemCount {
                  r[:data][:item_count].each do |ic|
                    xml.unsignedLong ic
                  end
                }
              }
            }
          end
        }
      end

      xml_results.to_xml
    end
  end
end
