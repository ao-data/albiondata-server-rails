describe MarketHistoryProcessorService, type: :service do

  describe '.ticks_to_time' do

    it 'converts ticks to time object' do
      ticks = 638486460000000000
      expected_datetime = DateTime.parse("2024-04-13 23:00:00 +0000")
      expect(MarketHistoryProcessorService.ticks_to_time(ticks)).to eq(expected_datetime)
    end

    before do
      MarketHistory.destroy_all
      allow(REDIS).to receive(:get).and_return(nil)
      allow(REDIS).to receive(:set)
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
                         "SilverAmount": 960000,
                         "Timestamp": 638464104000000000
                       }
                     ]
                   }.to_json)
      }

      it 'creates new records' do
        expect { MarketHistoryProcessorService.process(data) }.to change { MarketHistory.count }.by(1)
      end

      it 'updates existing records' do
        MarketHistoryProcessorService.process(data)
        old_record_amount = MarketHistory.first['item_amount']
        sleep 1

        data['MarketHistories'][0]['ItemAmount'] = 25
        json_data = data.to_json
        data = JSON.parse(json_data)
        MarketHistoryProcessorService.process(data)
        new_record = MarketHistory.first

        expect(old_record_amount).not_to eq(new_record['item_amount'])
        expect(new_record['item_amount']).to eq(25)
      end

      it 'does not update a record if the data is the same' do
        MarketHistoryProcessorService.process(data)
        old_record = MarketHistory.first
        sleep 1

        MarketHistoryProcessorService.process(data)
        new_record = MarketHistory.first

        expect(old_record['item_amount']).to eq(new_record['item_amount'])
      end

      it 'does not attempt to lookup a record if it is cached in redis' do
        allow(REDIS).to receive(:get).and_return(1)
        expect(MarketHistory).not_to receive(:find_by)
        MarketHistoryProcessorService.process(data)
      end

      it 'processes the record with expected values' do
        MarketHistoryProcessorService.process(data)
        record = MarketHistory.first

        expect(record['item_id']).to eq('T4_BAG')
        expect(record['location']).to eq(3005)
        expect(record['quality']).to eq(1)
        expect(record['item_amount']).to eq(24)
        expect(record['silver_amount']).to eq(960000)
        expect(record['aggregation']).to eq(1)
        expect(record['timestamp'].utc.to_datetime.strftime('%Y-%m-%dT%H:%M:%S')).to eq("2024-03-19T02:00:00")
      end
    end
  end

end