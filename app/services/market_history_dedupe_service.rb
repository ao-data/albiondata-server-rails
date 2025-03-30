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
    # Parse and validate location
    data['LocationId'] = parse_location_integer(data['LocationId'])
    if data['LocationId'].nil?
      IdentifierService.add_identifier_event(opts, server_id, "Received on MarketHistoryDedupeService, invalid LocationId: #{data['LocationId']}")
      return
    end

    json_data = data.to_json
    json_opts = opts.to_json

    nats = NatsService.new(server_id)
    nats.send('markethistories.ingest', json_data)
    IdentifierService.add_identifier_event(opts, server_id, "Received on MarketHistoryDedupeService, sent to NATS markethistories.ingest")

    sha256 = Digest::SHA256.hexdigest(json_data)

    log = { class: 'MarketHistoryDedupeService', method: 'dedupe', server_id: server_id, opts: opts}

    metrics = { server_id: server_id, locations: {}}
    if REDIS[server_id].get("HISTORY_RECORD_SHA256:#{sha256}").nil?
      REDIS[server_id].set("HISTORY_RECORD_SHA256:#{sha256}", '1', ex: 600)

      return if data['AlbionId'] == 0 # sometimes the client sends us 0 for the numeric item id, we trash this data

      item_id = REDIS[server_id].hget('ITEM_IDS', data['AlbionId'])
      raise StandardError.new('MarketHistoryProcessorService: Item ID not found in redis.') if item_id.nil?

      data['AlbionIdString'] = item_id

      data['MarketHistories'].each do |history|
        history['SilverAmount'] = history['SilverAmount'].to_i / 10000
      end

      json_data = data.to_json

      nats.send('markethistories.deduped', json_data)

      MarketHistoryProcessorWorker.perform_async(json_data, server_id, json_opts)

      # metrics
      metrics[:locations][data['LocationId']] = { duplicates: 0, non_duplicates: 0 } if metrics[:locations][data['LocationId']].nil?
      metrics[:locations][data['LocationId']][:non_duplicates] += data['MarketHistories'].length

      log.merge!(data: data, message: 'data not duplicate')
      IdentifierService.add_identifier_event(opts, server_id, "Received on MarketHistoryDedupeService, not duplicate, sent to MarketHistoryProcessorWorker")
    else
      # metrics
      metrics[:locations][data['LocationId']] = { duplicates: 0, non_duplicates: 0 } if metrics[:locations][data['LocationId']].nil?
      metrics[:locations][data['LocationId']][:duplicates] += data['MarketHistories'].length

      log.merge!(message: 'data duplicate')
      IdentifierService.add_identifier_event(opts, server_id, "Received on MarketHistoryDedupeService, data is duplicate, ignored")
    end

    puts metrics

    ActiveSupport::Notifications.instrument('metrics.market_history_dedupe_service', metrics)

    Sidekiq.logger.info(log.to_json)

    nats.close
  end
end
