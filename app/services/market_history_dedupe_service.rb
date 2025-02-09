class MarketHistoryDedupeService
  # data = {
  #   "AlbionId": 944,
  #   "AlbionIdString": "T4_BAG",
  #   "LocationId": 3005,
  #   "QualityLevel": 1,
  #   "Timescale": 0,
  #   "MarketHistories": [
  #     {
  #       "ItemAmount": 24,
  #       "SilverAmount": 960000,
  #       "Timestamp": 638464104000000000
  #     }
  #   ]
  # }

  include Location

  def dedupe(data, server_id, opts)
    json_data = data.to_json
    json_opts = opts.to_json

    nats = NatsService.new(server_id)
    nats.send('markethistories.ingest', json_data)

    sha256 = Digest::SHA256.hexdigest(json_data)

    log = { class: 'MarketHistoryDedupeService', method: 'dedupe', server_id: server_id, opts: opts}

    if REDIS[server_id].get("HISTORY_RECORD_SHA256:#{sha256}").nil?
      REDIS[server_id].set("HISTORY_RECORD_SHA256:#{sha256}", '1', ex: 600)
      return if data['AlbionId'] == 0 # sometimes the client sends us 0 for the numeric item id, we trash this data
      return if !data['LocationId'].is_a?(Numeric) || !CITY_TO_LOCATION.has_value?(data['LocationId']) # we only want to process numeric location ids from known cities

      item_id = REDIS[server_id].hget('ITEM_IDS', data['AlbionId'])
      raise StandardError.new('MarketHistoryProcessorService: Item ID not found in redis.') if item_id.nil?

      data['AlbionIdString'] = item_id
      data['LocationId'] = PORTAL_TO_CITY[data['LocationId']] if PORTAL_TO_CITY.has_key?(data['LocationId'])

      data['MarketHistories'].each do |history|
        history['SilverAmount'] = history['SilverAmount'].to_i / 10000
      end

      json_data = data.to_json

      nats.send('markethistories.deduped', json_data)

      MarketHistoryProcessorWorker.perform_async(json_data, server_id, json_opts)

      log.merge!(data: data, message: 'data not duplicate')
      IdentifierService.add_identifier_event(opts, server_id, "Received on MarketHistoryDedupeService, not duplicate, sent to MarketHistoryProcessorWorker")
    else
      log.merge!(message: 'data duplicate')
      IdentifierService.add_identifier_event(opts, server_id, "Received on MarketHistoryDedupeService, data is duplicate, ignored")
    end

    Sidekiq.logger.info(log.to_json)

    nats.close
  end
end
