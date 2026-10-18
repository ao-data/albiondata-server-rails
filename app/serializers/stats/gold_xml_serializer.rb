module Stats
  class GoldXmlSerializer
    def self.call(results)
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
end
