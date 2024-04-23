class GoldProcessorService
  def self.process(data, server_id)
    Multidb.use(server_id.to_sym) do
      data['Prices'].each_with_index do |price, index|
        timestamp = Time.at((data['Timestamps'][index] - 621355968000000000)/10000000)
        GoldPrice.find_or_create_by(price: price, timestamp: timestamp)
      end
    end
  end
end
