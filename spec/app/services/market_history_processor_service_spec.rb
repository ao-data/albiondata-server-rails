describe MarketHistoryProcessorService, type: :service do

  describe '.ticks_to_time' do

    it 'converts ticks to time object' do
      ticks = 638486460000000000
      expected_datetime = DateTime.parse("2024-04-13 23:00:00 +0000")
      expect(subject.ticks_to_time(ticks)).to eq(expected_datetime)
    end

    before do
      Multidb.use(:west)
      MarketHistory.destroy_all
      allow(REDIS['west']).to receive(:get).and_return(nil)
      allow(REDIS['west']).to receive(:set)
    end

    describe '.process' do
      let(:data) {
        JSON.parse({
                     "AlbionId": 944,
                     "AlbionIdString": "T4_BAG",
                     "LocationId": 3005,
                     "QualityLevel": 1,
                     "Timescale": 0,
                     "MarketHistories": [
                       {
                         "ItemAmount": 24,
                         "SilverAmount": 96,
                         "Timestamp": 638464104000000000
                       }
                     ]
                   }.to_json)
      }
      let(:opts) { { 'baz' => 'qux' } }

      it 'creates new records' do
        expect { subject.process(data, 'west', opts) }.to change { MarketHistory.count }.by(1)
      end

      it 'updates existing records' do
        subject.process(data, 'west', opts)
        old_record_amount = MarketHistory.first['item_amount']
        Timecop.freeze(Time.now + 1.second)

        data['MarketHistories'][0]['ItemAmount'] = 25
        json_data = data.to_json
        data = JSON.parse(json_data)
        subject.process(data, 'west', opts)
        new_record = MarketHistory.first

        expect(old_record_amount).not_to eq(new_record['item_amount'])
        expect(new_record['item_amount']).to eq(25)
      end

      it 'does not update a record if the data is the same' do
        subject.process(data, 'west', opts)
        old_record = MarketHistory.first
        Timecop.freeze(Time.now + 1.second)

        subject.process(data, 'west', opts)
        new_record = MarketHistory.first

        expect(old_record['item_amount']).to eq(new_record['item_amount'])
      end

      it 'does not attempt to lookup a record if it is cached in redis' do
        allow(REDIS['west']).to receive(:get).and_return(1)
        expect(MarketHistory).not_to receive(:find_by)
        subject.process(data, 'west', opts)
      end

      it 'uses the correct database' do
        expect(Multidb).to receive(:use).with(:east)
        subject.process(data, 'east', opts)
      end

      it 'processes the record with expected values' do
        MarketHistoryProcessorService.new.process(data, 'west', opts)
        record = MarketHistory.first

        expect(record['item_id']).to eq('T4_BAG')
        expect(record['location']).to eq(3005)
        expect(record['quality']).to eq(1)
        expect(record['item_amount']).to eq(24)
        expect(record['silver_amount']).to eq(96)
        expect(record['aggregation']).to eq(1)
        expect(record['timestamp'].utc.to_datetime.strftime('%Y-%m-%dT%H:%M:%S')).to eq("2024-03-19T02:00:00")
      end

      it 'sends logs' do
        expected_record_data = [
          {
            item_id: 'T4_BAG',
            quality: 1,
            location: 3005,
            timestamp: DateTime.parse("2024-03-19 02:00:00 +0000"),
            aggregation: 1,
            item_amount: 24,
            silver_amount: 96
          }
        ]

        expected_log = { class: 'MarketHistoryProcessorService', method: 'process', server_id: 'west', opts: opts, record_data: expected_record_data }
        expect(Sidekiq.logger).to receive(:info).with(expected_log.to_json)
        subject.process(data, 'west', opts)
      end
    end
  end
end