class GoldProcessorService
  def self.process(data)
    data['Prices'].each_with_index do |price, index|
      pp "Processing gold price: #{price} at timestamp: #{data['Timestamps'][index]}"
      timestamp = Time.at((data['Timestamps'][index] / 10000 - 62136892800000) / 1000)
      GoldPrice.find_or_create_by(price: price, timestamp: timestamp)
    end
  end
end
