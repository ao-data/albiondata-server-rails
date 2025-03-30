describe MarketHistoryDedupeService, type: :service do

  describe '.dedupe' do
    let(:opts) { { 'baz' => 'qux' } }
    let(:data) { { 'LocationId' => 3005, 'AlbionId' => 1234, 'MarketHistories' => [], 'foo' => 'bar' } }
    let(:expected_data) { { 'LocationId' => 3005, 'AlbionId' => 1234, 'MarketHistories' => [], 'foo' => 'bar', 'AlbionIdString' => 'SOME_ITEM_ID' } }

    it 'does not process if the sha256 hash is found in redis' do
      data = { 'foo' => 'bar', 'MarketHistories' => [] }
      json_data = data.to_json
      sha256 = Digest::SHA256.hexdigest(json_data)
      allow(REDIS['west']).to receive(:get).with("HISTORY_RECORD_SHA256:#{sha256}").and_return('1')
      expect(NatsService).not_to receive(:send)
      expect(MarketHistoryProcessorWorker).not_to receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end

    it 'returns nil if AlbionId is 0' do
      data['AlbionId'] = 0
      expect(subject.dedupe(data, 'west', opts)).to eq(nil)
    end

    it 'returns nil if LocationId is not a valid market locationId' do
      expect(subject.dedupe(data, 'west', opts)).to eq(nil)
    end

    it 'returns nil if LocationId is not a numeric' do
      expect(subject.dedupe(data, 'west', opts)).to eq(nil)
    end

    it 'returns a StandardError if the AlbionID is not found in redis' do
      allow(REDIS['west']).to receive(:get).and_return(nil)
      allow(REDIS['west']).to receive(:hget).with('ITEM_IDS', 1234).and_return(nil)
      expect { subject.dedupe(data, 'west', opts) }.to raise_error(StandardError)
    end

    it 'sends data to NatsService and MarketHistoryProcessorWorker' do
      allow(REDIS['west']).to receive(:get).and_return(nil)
      allow(REDIS['west']).to receive(:hget).with('ITEM_IDS', 1234).and_return('SOME_ITEM_ID')

      nats = double
      expect(nats).to receive(:send).with('markethistories.ingest', data.to_json)
      expect(nats).to receive(:send).with('markethistories.deduped', expected_data.to_json)
      allow(nats).to receive(:close)
      allow(NatsService).to receive(:new).with('west').and_return(nats)

      expect(MarketHistoryProcessorWorker).to receive(:perform_async).with(expected_data.to_json, 'west', opts.to_json)
      subject.dedupe(data, 'west', opts)
    end

    it 'will convert the LocationId to the city id if it is a portal' do
      data['LocationId'] = 3013
      allow(REDIS['west']).to receive(:get).and_return(nil)
      allow(REDIS['west']).to receive(:hget).with('ITEM_IDS', 1234).and_return('SOME_ITEM_ID')

      nats = double
      allow(nats).to receive(:send)
      allow(nats).to receive(:close)
      allow(NatsService).to receive(:new).and_return(nats)

      expect(MarketHistoryProcessorWorker).to receive(:perform_async).with(expected_data.to_json, 'west', opts.to_json)
      subject.dedupe(data, 'west', opts)
    end

    it 'will not convert the LocationId if it is not a portal' do
      allow(REDIS['west']).to receive(:get).and_return(nil)
      allow(REDIS['west']).to receive(:hget).with('ITEM_IDS', 1234).and_return('SOME_ITEM_ID')

      nats = double
      allow(nats).to receive(:send)
      allow(nats).to receive(:close)
      allow(NatsService).to receive(:new).and_return(nats)

      expect(MarketHistoryProcessorWorker).to receive(:perform_async).with(expected_data.to_json, 'west', opts.to_json)
      subject.dedupe(data, 'west', opts)
    end

    it 'corrects the price of the MarketHistories' do
      data['MarketHistories'] = [{ 'SilverAmount' => '123456' }]
      expected_data['MarketHistories'] = [{ 'SilverAmount' => 12 }]
      allow(REDIS['west']).to receive(:get).and_return(nil)
      allow(REDIS['west']).to receive(:hget).with('ITEM_IDS', 1234).and_return('SOME_ITEM_ID')

      nats = double
      allow(nats).to receive(:send)
      allow(nats).to receive(:close)
      allow(NatsService).to receive(:new).and_return(nats)

      expect(MarketHistoryProcessorWorker).to receive(:perform_async).with(expected_data.to_json, 'west', opts.to_json)
      subject.dedupe(data, 'west', opts)
    end

    context 'when duplicate' do
      it 'logs with duplicate message' do
        json_data = data.to_json
        sha256 = Digest::SHA256.hexdigest(json_data)
        allow(REDIS['west']).to receive(:get).with("HISTORY_RECORD_SHA256:#{sha256}").and_return('1')
        expect(Sidekiq.logger).to receive(:info).with({ class: 'MarketHistoryDedupeService', method: 'dedupe', server_id: 'west', opts: opts, message: 'data duplicate' }.to_json)
        subject.dedupe(data, 'west', opts)
      end

      it 'sends an activesupport notification' do
        data['MarketHistories'] = [{ 'SilverAmount' => '123456' }]
        expected_payload = { server_id: 'west', locations: {3005 => { duplicates: 1, non_duplicates: 0 }} }
        expect(ActiveSupport::Notifications).to receive(:instrument).with('metrics.market_history_dedupe_service', expected_payload)
        allow(REDIS['west']).to receive(:get).and_return(true)
        subject.dedupe(data, 'west', opts)
      end
    end

    context 'when not duplicate' do
      it 'logs with not duplicate message' do
        data['MarketHistories'] = [{ 'SilverAmount' => '123456' }]
        expected_data['MarketHistories'] = [{ 'SilverAmount' => 12 }]
        allow(REDIS['west']).to receive(:get).and_return(nil)
        allow(REDIS['west']).to receive(:hget).with('ITEM_IDS', 1234).and_return('SOME_ITEM_ID')

        expected_log = { class: 'MarketHistoryDedupeService', method: 'dedupe', server_id: 'west', opts: opts, data: expected_data, message: 'data not duplicate' }
        expect(Sidekiq.logger).to receive(:info).with(expected_log.to_json)
        subject.dedupe(data, 'west', opts)
      end

      it 'sends an activesupport notification' do
        data = { 'foo' => 'bar', 'AlbionId' => 3005, 'LocationId' => 3005, 'MarketHistories' => [{ 'SilverAmount' => '234567' }] }
        expected_payload = { server_id: 'west', locations: {3005 => { duplicates: 0, non_duplicates: 1 }} }
        expect(ActiveSupport::Notifications).to receive(:instrument).with('metrics.market_history_dedupe_service', expected_payload)
        allow(REDIS['west']).to receive(:get).and_return(nil)
        subject.dedupe(data, 'west', opts)
      end
    end
  end
end
