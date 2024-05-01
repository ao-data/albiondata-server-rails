describe MarketHistoryDedupeService, type: :service do

  describe '.process' do
    it 'does not process if the sha256 hash is found in redis' do
      data = { 'foo' => 'bar' }
      json_data = data.to_json
      sha256 = Digest::SHA256.hexdigest(json_data)
      allow(REDIS).to receive(:get).with("HISTORY_RECORD_SHA256:#{sha256}").and_return('1')
      expect(NatsService).not_to receive(:send)
      expect(MarketHistoryProcessorWorker).not_to receive(:perform_async)
      MarketHistoryDedupeService.dedupe(data)
    end

    it 'returns nil if AlbionId is 0' do
      data = { 'AlbionId' => 0 }
      expect(MarketHistoryDedupeService.dedupe(data)).to eq(nil)
    end

    it 'returns a StandardError if the AlbionID is not found in redis' do
      data = { 'foo' => 'bar', 'AlbionId' => 1234 }
      allow(REDIS).to receive(:get).and_return(nil)
      allow(REDIS).to receive(:hget).with('ITEM_IDS', 1234).and_return(nil)
      expect { MarketHistoryDedupeService.dedupe(data) }.to raise_error(StandardError)
    end

    it 'sends data to NatsService and MarketHistoryProcessorWorker' do
      data = { 'foo' => 'bar', 'AlbionId' => 1234, 'MarketHistories' => [] }
      expected_data = { 'foo' => 'bar', 'AlbionId' => 1234, 'MarketHistories' => [], 'AlbionIdString' => 'SOME_ITEM_ID' }
      allow(REDIS).to receive(:get).and_return(nil)
      allow(REDIS).to receive(:hget).with('ITEM_IDS', 1234).and_return('SOME_ITEM_ID')

      nats_send = double
      expect(nats_send).to receive(:close)

      nats = double
      expect(nats).to receive(:send).with('markethistories.deduped', expected_data.to_json).and_return(nats_send)

      allow(NatsService).to receive(:new).and_return(nats)

      expect(MarketHistoryProcessorWorker).to receive(:perform_async).with(expected_data.to_json)
      MarketHistoryDedupeService.dedupe(data)
    end

    it 'will convert the LocationId to the city id if it is a portal' do
      data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 3013, 'MarketHistories' => [] }
      expected_data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 3005, 'MarketHistories' => [], 'AlbionIdString' => 'SOME_ITEM_ID', }
      allow(REDIS).to receive(:get).and_return(nil)
      allow(REDIS).to receive(:hget).with('ITEM_IDS', 1234).and_return('SOME_ITEM_ID')

      nats_send = double
      expect(nats_send).to receive(:close)

      nats = double
      expect(nats).to receive(:send).with('markethistories.deduped', expected_data.to_json).and_return(nats_send)

      allow(NatsService).to receive(:new).and_return(nats)

      expect(MarketHistoryProcessorWorker).to receive(:perform_async).with(expected_data.to_json)
      MarketHistoryDedupeService.dedupe(data)
    end

    it 'will not convert the LocationId if it is not a portal' do
      data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 1234, 'MarketHistories' => [] }
      expected_data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 1234, 'MarketHistories' => [], 'AlbionIdString' => 'SOME_ITEM_ID', }
      allow(REDIS).to receive(:get).and_return(nil)
      allow(REDIS).to receive(:hget).with('ITEM_IDS', 1234).and_return('SOME_ITEM_ID')

      nats_send = double
      expect(nats_send).to receive(:close)

      nats = double
      expect(nats).to receive(:send).with('markethistories.deduped', expected_data.to_json).and_return(nats_send)

      allow(NatsService).to receive(:new).and_return(nats)

      expect(MarketHistoryProcessorWorker).to receive(:perform_async).with(expected_data.to_json)
      MarketHistoryDedupeService.dedupe(data)
    end

    it 'corrects the price of the MarketHistories' do
      data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 1234, 'MarketHistories' => [{ 'SilverAmount' => '123456' }] }
      expected_data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 1234, 'MarketHistories' => [{ 'SilverAmount' => 12 }] , 'AlbionIdString' => 'SOME_ITEM_ID', }
      allow(REDIS).to receive(:get).and_return(nil)
      allow(REDIS).to receive(:hget).with('ITEM_IDS', 1234).and_return('SOME_ITEM_ID')

      nats_send = double
      expect(nats_send).to receive(:close)

      nats = double
      expect(nats).to receive(:send).with('markethistories.deduped', expected_data.to_json).and_return(nats_send)

      allow(NatsService).to receive(:new).and_return(nats)

      expect(MarketHistoryProcessorWorker).to receive(:perform_async).with(expected_data.to_json)
      MarketHistoryDedupeService.dedupe(data)
    end
  end
end