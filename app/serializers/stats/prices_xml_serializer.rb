module Stats
  class PricesXmlSerializer
    def self.call(sorted_results)
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
  end
end
