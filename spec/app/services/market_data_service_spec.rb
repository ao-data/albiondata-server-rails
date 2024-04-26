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
        expect(result[0][:city]).to eq('Caerleon')
        expect(result[1][:city]).to eq('Martlock')
      end

      it 'has item_id in the correct order' do
        result = subject.get_stats({id: 'T4_BAG,T5_BAG', locations: '3005'})
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


  end

  describe '#get_locations' do
    it 'returns default list of locations if locations is nil' do
      params = { locations: nil}
      expect(subject.get_locations(params)).to eq([4, 7, 301, 8, 1002, 1301, 1006, 1012, 2002, 2004, 2301, 3002, 3003, 3005, 3008, 3301, 4002, 4301, 4006, 4300, 5003])
    end

    it 'returns default list of locations if locations is 0' do
      params = { locations: 0}
      expect(subject.get_locations(params)).to eq([4, 7, 301, 8, 1002, 1301, 1006, 1012, 2002, 2004, 2301, 3002, 3003, 3005, 3008, 3301, 4002, 4301, 4006, 4300, 5003])
    end

    it 'returns empty list of locations if locations is an empty string' do
      params = { locations: ''}
      expect(subject.get_locations(params)).to eq([])
    end

    it 'returns empty list of locations if locations is an empty array' do
      params = { locations: []}
      expect(subject.get_locations(params)).to eq([])
    end

    it 'returns string converted locations if locations is a string' do
      params = { locations: 'martlock,caerleon2'}
      expect(subject.get_locations(params)).to eq([3008, 3005])
    end

    it 'returns string converted locations if locations is an array' do
      params = { locations: ['martlock', 'caerleon2']}
      expect(subject.get_locations(params)).to eq([3008, 3005])
    end

    it 'returns string converted locations if locations is an array with spaces' do
      params = { locations: ['fortsterling', 'caerleon 2']}
      expect(subject.get_locations(params)).to eq([4002, 3005])
    end
  end

  describe '#get_qualities' do
    it 'returns default list of qualities if qualities is nil' do
      params = { qualities: nil}
      expect(subject.get_qualities(params)).to eq([1])
    end

    it 'returns default list of qualities if qualities is 0' do
      params = { qualities: 0}
      expect(subject.get_qualities(params)).to eq([1,2,3,4,5])
    end

    it 'returns empty list of qualities if qualities is an empty string' do
      params = { qualities: ''}
      expect(subject.get_qualities(params)).to eq([])
    end

    it 'returns empty list of qualities if qualities is an empty array' do
      params = { qualities: []}
      expect(subject.get_qualities(params)).to eq([])
    end

    it 'returns string converted qualities if qualities is a string' do
      params = { qualities: '1,2'}
      expect(subject.get_qualities(params)).to eq([1,2])
    end

    it 'returns string converted qualities if qualities is an array' do
      params = { qualities: ['1', '2']}
      expect(subject.get_qualities(params)).to eq([1,2])
    end
  end

  describe '#humanize_city' do
    it 'returns a humanized city name' do
      expect(subject.humanize_city('martlock')).to eq('Martlock')
    end

    it 'returns a humanized city name with multiple words' do
      expect(subject.humanize_city('mountaincross')).to eq('Mountain Cross')
    end
  end

  describe '#location_to_city' do
    it 'returns a city name for a location' do
      expect(subject.location_to_city(3005)).to eq(:caerleon)
    end

    it 'returns a city name for a location as a string' do
      expect(subject.location_to_city('3005')).to eq(:caerleon)
    end

    it 'returns a location if there is no city name' do
      expect(subject.location_to_city(1234)).to eq(:'1234')
    end
  end

  describe '#city_to_location' do
    it 'returns a location for a city' do
      expect(subject.city_to_location(:caerleon)).to eq(3005)
    end

    it 'returns a location for a city as a string' do
      expect(subject.city_to_location('caerleon')).to eq(3005)
    end

    it 'returns a city if there is no location' do
      expect(subject.city_to_location('1234')).to eq(1234)
    end
  end
end