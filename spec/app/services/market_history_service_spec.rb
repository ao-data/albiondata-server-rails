require 'rails_helper'

RSpec.describe MarketHistoryService, :type => :service do
  before do
    Timecop.freeze(DateTime.parse('2024-03-10 00:00:00'))

    ['T4_BAG', 'T5_BAG'].product([1,2], [3003,3005], [8,9,10].to_a, [0, 6, 12, 18]).each do |item_id, quality, location, i, j|
      MarketHistory.create(item_id: item_id, quality: quality, location: location, item_amount: location * quality, silver_amount:  location * quality * 2, timestamp: DateTime.parse("2024-03-#{i} #{j}:00:00"), aggregation: 6)
    end

    ['T4_BAG', 'T5_BAG'].product([1], [3005], [9,10].to_a, (0..23).to_a).each do |item_id, quality, location, i, j|
      MarketHistory.create(item_id: item_id, quality: quality, location: location, item_amount: location * quality, silver_amount: location * quality * 2, timestamp: DateTime.parse("2024-03-#{i} #{j}:00:00"), aggregation: 1)
    end
  end

  after do
    Timecop.return
  end

  describe '#get_stats' do
    it 'uses all defaults with the exception of item_id' do
      params = { id: 'T4_BAG' }
      expect{subject.get_stats(params)}.not_to raise_error
    end

    it 'handles an unmapped city' do
      params = { id: 'T4_BAG', locations: '9999' }
      expect{subject.get_stats(params)}.not_to raise_error
    end

    context 'time-scale 24' do
      let(:timescale) { 24 }
      it 'returns only T4_BAG in location 3005 with quality 1 of 1 record per day' do
        params = { id: 'T4_BAG', locations: '3005', qualities: '1', 'time-scale': timescale }
        result = subject.get_stats(params)

        expected_result = {:location=>"Caerleon",
                           :item_id=>"T4_BAG",
                           :quality=>1,
                           :data=>
                             [{:item_count=>3005, :avg_price=>2, :timestamp=>"2024-03-07T00:00:00"},
                              {:item_count=>12020, :avg_price=>2, :timestamp=>"2024-03-08T00:00:00"},
                              {:item_count=>12020, :avg_price=>2, :timestamp=>"2024-03-09T00:00:00"}]}

        expect(result.count).to eq(1)
        expect(result[0]).to eq(expected_result)
      end

      it 'returns only T5_BAG in location 3003 with quality 1 of 1 record per day' do
        params = { id: 'T5_BAG', locations: '3003', qualities: '1', 'time-scale': timescale }
        result = subject.get_stats(params)

        expected_result = {:location=>"Black Market",
                           :item_id=>"T5_BAG",
                           :quality=>1,
                           :data=>
                             [{:item_count=>3003, :avg_price=>2, :timestamp=>"2024-03-07T00:00:00"},
                              {:item_count=>12012, :avg_price=>2, :timestamp=>"2024-03-08T00:00:00"},
                              {:item_count=>12012, :avg_price=>2, :timestamp=>"2024-03-09T00:00:00"}]}
        expect(result.count).to eq(1)
        expect(result[0]).to eq(expected_result)
      end

      it 'returns T4_BAG and T5_BAG in locations 3003 and 3005 with quality 1 and 2 for 3 days each' do
        params = { id: 'T4_BAG,T5_BAG', locations: '3003,3005', qualities: '1,2', 'time-scale': timescale }
        result = subject.get_stats(params)

        expect(result[0]).to eq({:location=>"Black Market",
                                  :item_id=>"T4_BAG",
                                  :quality=>1,
                                  :data=>
                                    [{:item_count=>3003, :avg_price=>2, :timestamp=>"2024-03-07T00:00:00"},
                                      {:item_count=>12012, :avg_price=>2, :timestamp=>"2024-03-08T00:00:00"},
                                      {:item_count=>12012, :avg_price=>2, :timestamp=>"2024-03-09T00:00:00"}]})

        expect(result[1]).to eq({:location=>"Black Market",
                                 :item_id=>"T4_BAG",
                                 :quality=>2,
                                 :data=>
                                   [{:item_count=>6006, :avg_price=>2, :timestamp=>"2024-03-07T00:00:00"},
                                    {:item_count=>24024, :avg_price=>2, :timestamp=>"2024-03-08T00:00:00"},
                                    {:item_count=>24024, :avg_price=>2, :timestamp=>"2024-03-09T00:00:00"}]})

        expect(result[2]).to eq({:location=>"Black Market",
                                 :item_id=>"T5_BAG",
                                 :quality=>1,
                                 :data=>
                                   [{:item_count=>3003, :avg_price=>2, :timestamp=>"2024-03-07T00:00:00"},
                                    {:item_count=>12012, :avg_price=>2, :timestamp=>"2024-03-08T00:00:00"},
                                    {:item_count=>12012, :avg_price=>2, :timestamp=>"2024-03-09T00:00:00"}]})

        expect(result[3]).to eq({:location=>"Black Market",
                                 :item_id=>"T5_BAG",
                                 :quality=>2,
                                 :data=>
                                   [{:item_count=>6006, :avg_price=>2, :timestamp=>"2024-03-07T00:00:00"},
                                    {:item_count=>24024, :avg_price=>2, :timestamp=>"2024-03-08T00:00:00"},
                                    {:item_count=>24024, :avg_price=>2, :timestamp=>"2024-03-09T00:00:00"}]})

        expect(result[4]).to eq({:location=>"Caerleon",
                                 :item_id=>"T4_BAG",
                                 :quality=>1,
                                 :data=>
                                   [{:item_count=>3005, :avg_price=>2, :timestamp=>"2024-03-07T00:00:00"},
                                    {:item_count=>12020, :avg_price=>2, :timestamp=>"2024-03-08T00:00:00"},
                                    {:item_count=>12020, :avg_price=>2, :timestamp=>"2024-03-09T00:00:00"}]})

        expect(result[5]).to eq({:location=>"Caerleon",
                                 :item_id=>"T4_BAG",
                                 :quality=>2,
                                 :data=>
                                   [{:item_count=>6010, :avg_price=>2, :timestamp=>"2024-03-07T00:00:00"},
                                    {:item_count=>24040, :avg_price=>2, :timestamp=>"2024-03-08T00:00:00"},
                                    {:item_count=>24040, :avg_price=>2, :timestamp=>"2024-03-09T00:00:00"}]})

        expect(result[6]).to eq({:location=>"Caerleon",
                                 :item_id=>"T5_BAG",
                                 :quality=>1,
                                 :data=>
                                   [{:item_count=>3005, :avg_price=>2, :timestamp=>"2024-03-07T00:00:00"},
                                    {:item_count=>12020, :avg_price=>2, :timestamp=>"2024-03-08T00:00:00"},
                                    {:item_count=>12020, :avg_price=>2, :timestamp=>"2024-03-09T00:00:00"}]})

        expect(result[7]).to eq({:location=>"Caerleon",
                                 :item_id=>"T5_BAG",
                                 :quality=>2,
                                 :data=>
                                   [{:item_count=>6010, :avg_price=>2, :timestamp=>"2024-03-07T00:00:00"},
                                    {:item_count=>24040, :avg_price=>2, :timestamp=>"2024-03-08T00:00:00"},
                                    {:item_count=>24040, :avg_price=>2, :timestamp=>"2024-03-09T00:00:00"}]})

      end
    end


    context 'time-scale 6' do
      let(:timescale) { 6 }

      it 'returns only id T4_BAG in location 3005 with quality 1 of 4 records per day + 1st record of next day' do
        params = { id: 'T4_BAG', locations: '3005', qualities: '1', 'time-scale': timescale }
        result = subject.get_stats(params)

        expect(result[0][:location]).to eq('Caerleon')
        expect(result[0][:item_id]).to eq('T4_BAG')
        expect(result[0][:quality]).to eq(1)
        expect(result[0][:data].size).to eq(9)
        expect(result[0][:data][0][:timestamp]).to eq('2024-03-08T00:00:00')
        expect(result[0][:data][1][:timestamp]).to eq('2024-03-08T06:00:00')
        expect(result[0][:data][2][:timestamp]).to eq('2024-03-08T12:00:00')
        expect(result[0][:data][3][:timestamp]).to eq('2024-03-08T18:00:00')
        expect(result[0][:data][4][:timestamp]).to eq('2024-03-09T00:00:00')
        expect(result[0][:data][5][:timestamp]).to eq('2024-03-09T06:00:00')
        expect(result[0][:data][6][:timestamp]).to eq('2024-03-09T12:00:00')
        expect(result[0][:data][7][:timestamp]).to eq('2024-03-09T18:00:00')
        expect(result[0][:data][8][:timestamp]).to eq('2024-03-10T00:00:00')
      end

    end

    context 'time-scale 1' do
      let(:timescale) { 1 }

      it 'returns only T4_BAG in location 3005 with quality 1 for 25 hours total (1 hour of the next day)' do
        params = { id: 'T4_BAG', locations: '3005', qualities: '1', 'time-scale': timescale, date: '2024-03-09', end_date: '2024-03-10'}
        result = subject.get_stats(params)

        expect(result[0][:location]).to eq('Caerleon')
        expect(result[0][:item_id]).to eq('T4_BAG')
        expect(result[0][:quality]).to eq(1)
        expect(result[0][:data].size).to eq(25)
        expect(result[0][:data][0][:timestamp]).to eq('2024-03-09T00:00:00')
        expect(result[0][:data][1][:timestamp]).to eq('2024-03-09T01:00:00')
        expect(result[0][:data][24][:timestamp]).to eq('2024-03-10T00:00:00')
      end
    end
  end
end
