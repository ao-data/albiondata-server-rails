describe MarketHistoryDedupeService, type: :service do

  describe '.dedupe' do
    let(:opts) { { 'baz' => 'qux' } }
    let(:nats) { double('nats', send: nil, close: nil) }

    before do
      keys = REDIS['west'].keys('HISTORY_RECORD_SHA256:*')
      REDIS['west'].del(keys) if keys.any?

      allow(NatsService).to receive(:new).and_return(nats)
      allow(REDIS['west']).to receive(:get).and_return(nil)
      allow(REDIS['west']).to receive(:set)
      allow(REDIS['west']).to receive(:hget).with('ITEM_IDS', 1234).and_return('SOME_ITEM_ID')
    end

    it 'it sends to NatsService with parsed LocationId as integer' do
      data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => '3005', 'MarketHistories' => [] }
      expect(nats).to receive(:send) do |topic, payload|
        parsed = JSON.parse(payload)
        expect(parsed['LocationId']).to eq(3005)
      end.at_least(:once)
      allow(MarketHistoryProcessorWorker).to receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end

    it 'it does not process if the sha256 hash is found in redis' do
      data = { 'foo' => 'bar' }
      json_data = data.to_json
      sha256 = Digest::SHA256.hexdigest(json_data)
      allow(REDIS['west']).to receive(:get).with("HISTORY_RECORD_SHA256:#{sha256}").and_return('1')
      expect(NatsService).not_to receive(:send)
      expect(MarketHistoryProcessorWorker).not_to receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end

    it 'it does not call MarketHistoryProcessorWorker if AlbionId is 0' do
      data = { 'AlbionId' => 0 }
      expect(MarketHistoryProcessorWorker).to_not receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end

    it 'it does not call MarketHistoryProcessorWorker if LocationId is a random word' do
      data = { 'AlbionId' => 1234, 'LocationId' => 'pizza', 'MarketHistories' => [] }
      expect(MarketHistoryProcessorWorker).to_not receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end

    it 'it does not call MarketHistoryProcessorWorker if LocationId is not a valid market locationId' do
      data = { 'AlbionId' => 1234, 'LocationId' => 0, 'MarketHistories' => [] }
      expect(MarketHistoryProcessorWorker).to_not receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end 

    it 'it does not call MarketHistoryProcessorWorker if LocationId has @ and a invalid numeric' do
      data = { 'AlbionId' => 1234, 'LocationId' => 'LOTSOFSTUFF@6969', 'MarketHistories' => [] }
      expect(MarketHistoryProcessorWorker).to_not receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end

    it 'it calls MarketHistoryProcessorWorker if LocationId is a valid numeric' do
      data = { 'AlbionId' => 1234, 'LocationId' => 3005, 'MarketHistories' => [] }
      expect(MarketHistoryProcessorWorker).to receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end

    it 'it calls MarketHistoryProcessorWorker if LocationId is a valid numeric (portal)' do
      data = { 'AlbionId' => 1234, 'LocationId' => 301, 'MarketHistories' => [] }
      expect(MarketHistoryProcessorWorker).to receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end

    it 'it calls MarketHistoryProcessorWorker if LocationId is not a numeric' do
      data = { 'AlbionId' => 1234, 'LocationId' => '3005', 'MarketHistories' => [] }
      expect(MarketHistoryProcessorWorker).to receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end

    it 'it calls MarketHistoryProcessorWorker if LocationId is a HellDens locationId' do
      data = { 'AlbionId' => 1234, 'LocationId' => '0000-HellDen', 'MarketHistories' => [] }
      expect(MarketHistoryProcessorWorker).to receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end

    it 'it calls MarketHistoryProcessorWorker if LocationId is a Blackbank locationId' do
      data = { 'AlbionId' => 1234, 'LocationId' => 'BLACKBANK-2311', 'MarketHistories' => [] }
      expect(MarketHistoryProcessorWorker).to receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end

    it 'it calls MarketHistoryProcessorWorker if LocationId is a Blackbank locationId with @' do
      data = { 'AlbionId' => 1234, 'LocationId' => 'LOTSOFSTUFF@BLACKBANK-2311', 'MarketHistories' => [] }
      expect(MarketHistoryProcessorWorker).to receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end

    it 'it calls MarketHistoryProcessorWorker if LocationId has @ and a valid numeric' do
      data = { 'AlbionId' => 1234, 'LocationId' => 'LOTSOFSTUFF@0008', 'MarketHistories' => [] }
      expect(MarketHistoryProcessorWorker).to receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end

    it 'it calls MarketHistoryProcessorWorker if LocationId is Caerleon second market (3013-Auction2)' do
      data = { 'AlbionId' => 1234, 'LocationId' => '3013-Auction2', 'MarketHistories' => [] }
      expect(MarketHistoryProcessorWorker).to receive(:perform_async)
      subject.dedupe(data, 'west', opts)
    end

    it 'it returns a StandardError if the AlbionID is not found in redis' do
      data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 3005 }
      allow(REDIS['west']).to receive(:hget).with('ITEM_IDS', 1234).and_return(nil)
      expect { subject.dedupe(data, 'west', opts) }.to raise_error(StandardError)
    end

    it 'it sends data to NatsService and MarketHistoryProcessorWorker' do
      data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 3005, 'MarketHistories' => [] }
      expected_data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 3005, 'MarketHistories' => [], 'AlbionIdString' => 'SOME_ITEM_ID' }
      
      expect(nats).to receive(:send).with('markethistories.ingest', data.to_json)
      expect(nats).to receive(:send).with('markethistories.deduped', expected_data.to_json)
      
      expect(MarketHistoryProcessorWorker).to receive(:perform_async).with(expected_data.to_json, 'west', opts.to_json)
      subject.dedupe(data, 'west', opts)
    end

    it 'it will convert the LocationId to the city id if it is a portal' do
      data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 3013, 'MarketHistories' => [] }
      expected_data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 3005, 'MarketHistories' => [], 'AlbionIdString' => 'SOME_ITEM_ID', }
      
      expect(MarketHistoryProcessorWorker).to receive(:perform_async).with(expected_data.to_json, 'west', opts.to_json)
      subject.dedupe(data, 'west', opts)
    end

    it 'it will not convert the LocationId if it is not a portal' do
      data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 3005, 'MarketHistories' => [] }
      expected_data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 3005, 'MarketHistories' => [], 'AlbionIdString' => 'SOME_ITEM_ID', }
      
      expect(MarketHistoryProcessorWorker).to receive(:perform_async).with(expected_data.to_json, 'west', opts.to_json)
      subject.dedupe(data, 'west', opts)
    end

    it 'it corrects the price of the MarketHistories' do
      data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 3005, 'MarketHistories' => [{ 'SilverAmount' => '123456' }] }
      expected_data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 3005, 'MarketHistories' => [{ 'SilverAmount' => 12 }] , 'AlbionIdString' => 'SOME_ITEM_ID', }
      
      expect(MarketHistoryProcessorWorker).to receive(:perform_async).with(expected_data.to_json, 'west', opts.to_json)
      subject.dedupe(data, 'west', opts)
    end

    it 'it logs with duplicate message' do
      data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 3005, 'MarketHistories' => [] }
      json_data = data.to_json
      sha256 = Digest::SHA256.hexdigest(json_data)
      allow(REDIS['west']).to receive(:get).with("HISTORY_RECORD_SHA256:#{sha256}").and_return('1')
      expect(Sidekiq.logger).to receive(:info).with({ class: 'MarketHistoryDedupeService', method: 'dedupe', server_id: 'west', opts: opts, message: 'data duplicate' }.to_json)
      subject.dedupe(data, 'west', opts)
    end

    it 'it logs with not duplicate message' do
      data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 3005, 'MarketHistories' => [] }
      expected_data = { 'foo' => 'bar', 'AlbionId' => 1234, 'LocationId' => 3005, 'MarketHistories' => [], 'AlbionIdString' => 'SOME_ITEM_ID' }
      
      expected_log = { class: 'MarketHistoryDedupeService', method: 'dedupe', server_id: 'west', opts: opts, data: expected_data, message: 'data not duplicate' }
      expect(Sidekiq.logger).to receive(:info).with(expected_log.to_json)
      subject.dedupe(data, 'west', opts)
    end
  end
end