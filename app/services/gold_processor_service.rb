class GoldProcessorService
  def process(data, server_id, opts)
    log = { class: 'GoldProcessorService', method: 'process', data: data, server_id: server_id, opts: opts }
    Sidekiq.logger.info(log.to_json)

    Multidb.use(server_id.to_sym) do
      data['Prices'].each_with_index do |price, index|
        timestamp = Time.at((data['Timestamps'][index] - 621355968000000000)/10000000)
        GoldPrice.find_or_create_by(price: price, timestamp: timestamp)
      end
    end
  end
end
