require 'rails_helper'

RSpec.describe MarketDataService, :type => :service do
  before do
    Timecop.freeze(DateTime.parse('2024-03-10 00:00:00'))
  end

  after do
    Timecop.return
  end

  describe '#get_stats' do
    it 'handles location ids that do not have string conversions' do
      create(:market_order_new_offer_low)
      result = subject.get_stats({id: 'T4_BAG', locations: '1234,3005', qualities: '1'})
      expect(result[0][:city]).to eq('1234')
      expect(result[1][:city]).to eq('Caerleon')
    end

    it 'returns the correct number of results' do
      create(:market_order_new_offer_low)
      create(:market_order_old_offer_high)
      result = subject.get_stats({id: 'T4_BAG', locations: '3005', qualities: '1'})
      expect(result.length).to eq(1)
    end

    context 'sell_price' do
      it 'returns the correct dates when there is only 1 new order' do
        create(:market_order_new_offer_low)
        result = subject.get_stats({id: 'T4_BAG', locations: '3005', qualities: '1'})
        expect(result[0][:sell_price_min_date]).to eq('2024-03-09T09:00:00')
        expect(result[0][:sell_price_max_date]).to eq('2024-03-09T09:00:00')
      end

      it 'returns the same dates when there is 1 old and 1 new record' do
        create(:market_order_new_offer_low)
        create(:market_order_old_offer_high)
        create(:market_order_old_offer_low)
        result = subject.get_stats({id: 'T4_BAG', locations: '3005', qualities: '1'})
        expect(result[0][:sell_price_min_date]).to eq('2024-03-09T09:00:00')
        expect(result[0][:sell_price_max_date]).to eq('2024-03-09T09:00:00')
      end

      it 'returns the correct min and max prices when there is only 1 new order' do
        create(:market_order_new_offer_low)
        result = subject.get_stats({id: 'T4_BAG', locations: '3005', qualities: '1'})
        expect(result[0][:sell_price_min]).to eq(10)
        expect(result[0][:sell_price_max]).to eq(10)
      end

      it 'returns the correct min and max prices when there are 2 new orders' do
        create(:market_order_new_offer_low)
        create(:market_order_new_offer_high)
        result = subject.get_stats({id: 'T4_BAG', locations: '3005', qualities: '1'})
        expect(result[0][:sell_price_min]).to eq(10)
        expect(result[0][:sell_price_max]).to eq(99)
      end

      it 'returns only the newest min and max prices when there are 2 new orders and 2 old orders' do
        create(:market_order_new_offer_low)
        create(:market_order_new_offer_high, price: 999)
        create(:market_order_old_offer_low, price: 1)
        create(:market_order_old_offer_high)
        result = subject.get_stats({id: 'T4_BAG', locations: '3005', qualities: '1'})
        expect(result[0][:sell_price_min]).to eq(10)
        expect(result[0][:sell_price_max]).to eq(999)
      end
    end

    context 'buy_price' do
      it 'returns the correct dates when there is only 1 new order' do
        create(:market_order_new_request_low)
        result = subject.get_stats({id: 'T4_BAG', locations: '3005', qualities: '1'})
        expect(result[0][:buy_price_min_date]).to eq('2024-03-09T09:00:00')
        expect(result[0][:buy_price_max_date]).to eq('2024-03-09T09:00:00')
      end

      it 'returns the same dates when there is 1 old and 1 new record' do
        create(:market_order_new_request_low)
        create(:market_order_old_request_high)
        result = subject.get_stats({id: 'T4_BAG', locations: '3005', qualities: '1'})
        expect(result[0][:buy_price_min_date]).to eq('2024-03-09T09:00:00')
        expect(result[0][:buy_price_max_date]).to eq('2024-03-09T09:00:00')
      end

      it 'returns the correct min and max prices when there is only 1 new order' do
        create(:market_order_new_request_low)
        result = subject.get_stats({id: 'T4_BAG', locations: '3005', qualities: '1'})
        expect(result[0][:buy_price_min]).to eq(10)
        expect(result[0][:buy_price_max]).to eq(10)
      end

      it 'returns the correct min and max prices when there are 2 new orders' do
        create(:market_order_new_request_low)
        create(:market_order_new_request_high)
        result = subject.get_stats({id: 'T4_BAG', locations: '3005', qualities: '1'})
        expect(result[0][:buy_price_min]).to eq(10)
        expect(result[0][:buy_price_max]).to eq(99)
      end

      it 'returns only the newest min and max prices when there are 2 new orders and 2 old orders' do
        create(:market_order_new_request_low)
        create(:market_order_new_request_high, price: 999)
        create(:market_order_old_request_low, price: 1)
        create(:market_order_old_request_high)
        result = subject.get_stats({id: 'T4_BAG', locations: '3005', qualities: '1'})
        expect(result[0][:buy_price_min]).to eq(10)
        expect(result[0][:buy_price_max]).to eq(999)
      end
    end

    context 'sorting' do
      it 'has locations in the correct order' do
        result = subject.get_stats({id: 'T4_BAG', locations: '3005,3008'})
        (0..4).each do |i|
          expect(result[i][:city]).to eq('Caerleon')
        end
        (5..9).each do |i|
          expect(result[i][:city]).to eq('Martlock')
        end
      end

      it 'has item_id in the correct order' do
        result = subject.get_stats({id: 'T4_BAG,T5_BAG', locations: '3005', qualities: '1'})
        expect(result[0][:item_id]).to eq('T4_BAG')
        expect(result[1][:item_id]).to eq('T5_BAG')
      end

      it 'has qualities in the correct order' do
        result = subject.get_stats({id: 'T4_BAG', locations: '3005', qualities: '1,2'})
        expect(result[0][:quality]).to eq(1)
        expect(result[1][:quality]).to eq(2)
      end

      it 'has item_ids, locations and qualities in the correct order' do
        result = subject.get_stats({id: 'T4_BAG,T5_BAG', locations: '3005,3008', qualities: '1,2'})
        expect(result[0][:item_id]).to eq('T4_BAG')
        expect(result[0][:city]).to eq('Caerleon')
        expect(result[0][:quality]).to eq(1)

        expect(result[1][:item_id]).to eq('T4_BAG')
        expect(result[1][:city]).to eq('Caerleon')
        expect(result[1][:quality]).to eq(2)

        expect(result[2][:item_id]).to eq('T4_BAG')
        expect(result[2][:city]).to eq('Martlock')
        expect(result[2][:quality]).to eq(1)

        expect(result[3][:item_id]).to eq('T4_BAG')
        expect(result[3][:city]).to eq('Martlock')
        expect(result[3][:quality]).to eq(2)

        expect(result[4][:item_id]).to eq('T5_BAG')
        expect(result[4][:city]).to eq('Caerleon')
        expect(result[4][:quality]).to eq(1)

        expect(result[5][:item_id]).to eq('T5_BAG')
        expect(result[5][:city]).to eq('Caerleon')
        expect(result[5][:quality]).to eq(2)

        expect(result[6][:item_id]).to eq('T5_BAG')
        expect(result[6][:city]).to eq('Martlock')
        expect(result[6][:quality]).to eq(1)

        expect(result[7][:item_id]).to eq('T5_BAG')
        expect(result[7][:city]).to eq('Martlock')
        expect(result[7][:quality]).to eq(2)
      end

      it 'sorts T4_LEATHER in Martlock before T4_LEATHER_LEVEL1@1' do
        # Notes: when using _ for the keys, T4_LEATHER_MARTLOCK comes after T4_LEATHER_LEVEL1@1_MARTLOCK because "T4_LEATHER_M" and "T4_LEATHER_L" sorting.
        # We don't want that. Key name separator is now !!.
        MarketOrder.delete_all
        ids = 'T4_LEATHER_LEVEL1@1,T4_LEATHER_LEVEL2@2,T4_LEATHER_LEVEL3@3,T4_LEATHER_LEVEL4@4,T4_LEATHER,T3_LEATHER'
        result = subject.get_stats({id: ids, locations: 'Martlock', qualities: '1'})
        expect(result[0][:item_id]).to eq('T3_LEATHER')
        expect(result[1][:item_id]).to eq('T4_LEATHER')
        expect(result[2][:item_id]).to eq('T4_LEATHER_LEVEL1@1')
      end
    end

    context 'smugglers dens' do
      it 'returns the correct number of results' do
        create(:market_order_new_offer_low, location: Location::SMUGGLERS_DEN_LOCATIONS[0])
        create(:market_order_new_offer_low, location: Location::SMUGGLERS_DEN_LOCATIONS[1])
        create(:market_order_new_offer_low, location: Location::SMUGGLERS_DEN_LOCATIONS[2])
        create(:market_order_new_offer_low, location: Location::SMUGGLERS_DEN_LOCATIONS[3])
        result = subject.get_stats({id: 'T4_BAG', locations: Location::SMUGGLERS_DEN_LOCATIONS[0].to_s, qualities: '1'})

        expect(result.length).to eq(Location::SMUGGLERS_DEN_LOCATIONS.length)
      end
    end
    it 'doesnt return 2 of the same item_id for thetford and a T7 item' do
      # it was replacing "7" with "Thetford" so the key ended up being "TThetford_item!!Thetford!!1" instead of "T7_item!!Thetford!!1"
      create(:market_order_new_offer_low, item_id: 'T7_BAG', location: 7)
      result = subject.get_stats({id: 'T7_BAG', locations: '7', qualities: '1'})
      expect(result.length).to eq(1)
    end
  end

end
