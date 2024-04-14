class GoldProcessorService
  def self.process(data)
    data['Prices'].each_with_index do |price, index|
      timestamp = Time.at((data['Timestamps'][index] - 621355968000000000)/10000000)
      GoldPrice.find_or_create_by(price: price, timestamp: timestamp)
    end
  end
end
