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
                         "Timestamp": 638464104000000000 # 2024-03-19T02:00:00Z
                       },
                       {
                         "ItemAmount": 30,
                         "SilverAmount": 120,
                         "Timestamp": 638464140000000000 # 2024-03-19T03:00:00Z
                       }
                     ]
                   }.to_json)
      }
      let(:opts) { { 'baz' => 'qux' } }

      it 'creates new records from a batch' do
        expect { subject.process(data, 'west', opts) }.to change { MarketHistory.count }.by(2)
      end

      it 'replaces existing records in the timeframe' do
        # Initial import
        subject.process(data, 'west', opts)
        expect(MarketHistory.count).to eq(2)
        expect(MarketHistory.find_by(item_amount: 24)).not_to be_nil

        # Create new data for the same timeframe but with different amounts
        modified_data = data.deep_dup
        modified_data['MarketHistories'][0]['ItemAmount'] = 100
        modified_data['MarketHistories'][1]['ItemAmount'] = 200

        # Process the new data
        subject.process(modified_data, 'west', opts)

        # Assert that the total count is the same, but the old records are gone and new ones are present
        expect(MarketHistory.count).to eq(2)
        expect(MarketHistory.find_by(item_amount: 24)).to be_nil
        expect(MarketHistory.find_by(item_amount: 100)).not_to be_nil
        expect(MarketHistory.find_by(item_amount: 200)).not_to be_nil
      end

      it 'does not process if timeframe is too large' do
        data['MarketHistories'] << {
          "ItemAmount" => 50,
          "SilverAmount" => 200,
          "Timestamp" => 638524104000000000 # ~69 days later 2024-05-27​T12:40:00.000Z
        }
        expect(Sidekiq.logger).to receive(:warn).with(/Unexpected timeframe/)
        expect { subject.process(data, 'west', opts) }.not_to(change { MarketHistory.count })
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

      it 'processes the records with expected values' do
        MarketHistoryProcessorService.new.process(data, 'west', opts)
        first_record = MarketHistory.first
        last_record = MarketHistory.last

        expect(first_record['item_id']).to eq('T4_BAG')
        expect(first_record['location']).to eq(3005)
        expect(first_record['quality']).to eq(1)
        expect(first_record['item_amount']).to eq(24)
        expect(first_record['silver_amount']).to eq(96)
        expect(first_record['aggregation']).to eq(1)
        expect(first_record['timestamp'].utc.to_datetime.strftime('%Y-%m-%dT%H:%M:%S')).to eq("2024-03-19T02:00:00")

        expect(last_record['item_amount']).to eq(30)
        expect(last_record['timestamp'].utc.to_datetime.strftime('%Y-%m-%dT%H:%M:%S')).to eq("2024-03-19T03:00:00")
      end

      it 'sends logs' do
        expected_record_data = [
          {
            item_id: 'T4_BAG',
            quality: 1,
            location: 3005,
            timestamp: subject.ticks_to_time(638464104000000000),
            aggregation: 1,
            item_amount: 24,
            silver_amount: 96
          },
          {
            item_id: 'T4_BAG',
            quality: 1,
            location: 3005,
            timestamp: subject.ticks_to_time(638464140000000000),
            aggregation: 1,
            item_amount: 30,
            silver_amount: 120
          }
        ]

        expected_log = { class: 'MarketHistoryProcessorService', method: 'process', server_id: 'west', opts: opts, record_data: expected_record_data }
        expect(Sidekiq.logger).to receive(:info).with(expected_log.to_json)
        subject.process(data, 'west', opts)
      end
    end
  end
end