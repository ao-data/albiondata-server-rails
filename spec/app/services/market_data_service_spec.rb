require 'rails_helper'

RSpec.describe MarketDataService, :type => :service do
  let!(:order1) { create(:market_order_new_offer_low) }
  let!(:order2) { create(:market_order_new_offer_high) }
  let!(:order3) { create(:market_order_old_offer_low) }
  let!(:order4) { create(:market_order_old_offer_high) }
  let!(:order5) { create(:market_order_old_request_low) }
  let!(:order6) { create(:market_order_old_request_high) }
  let!(:order7) { create(:market_order_oldest_request_low) }
  let!(:order8) { create(:market_order_oldest_request_high) }

  let(:params) { {id: 'T4_BAG', locations: '3005', qualities: '1' } }
  let(:subject) { described_class.new(params) }

  let(:new_binned_date) { DateTime.parse('2024-03-09 09:00:00').strftime('%Y-%m-%dT%H:%M:%S') }
  let(:old_binned_date) { DateTime.parse('2024-03-09 08:30:00').strftime('%Y-%m-%dT%H:%M:%S') }
  let(:oldest_binned_date) { DateTime.parse('2024-03-09 08:10:00').strftime('%Y-%m-%dT%H:%M:%S') }
  let(:no_binned_date) { DateTime.parse('0001-01-01 00:00:00').strftime('%Y-%m-%dT%H:%M:%S') }

  describe 'when item has data' do
    it 'only row has data' do
      result = subject.get_stats
      i = result[0]
      expect(result.count).to eq(1)
      expect(i[:item_id]).to eq('T4_BAG')
      expect(i[:quality]).to eq(1)
      expect(i[:sell_price_min]).to eq(10)
      expect(i[:sell_price_min_date]).to eq(new_binned_date)
      expect(i[:sell_price_max]).to eq(99)
      expect(i[:sell_price_max_date]).to eq(new_binned_date)
      expect(i[:buy_price_min]).to eq(10)
      expect(i[:buy_price_min_date]).to eq(old_binned_date)
      expect(i[:buy_price_max]).to eq(99)
      expect(i[:buy_price_max_date]).to eq(old_binned_date)
    end
  end

  describe 'with 2nd item that has no data' do
    it '2nd row default data' do
      params.merge!({ id: 'T4_BAG,T5_BAG'})
      result = subject.get_stats
      i = result[1]
      expect(result.count).to eq(2)
      expect(i[:item_id]).to eq('T5_BAG')
      expect(i[:quality]).to eq(1)
      expect(i[:sell_price_min]).to eq(0)
      expect(i[:sell_price_min_date]).to eq(no_binned_date)
      expect(i[:sell_price_max]).to eq(0)
      expect(i[:sell_price_max_date]).to eq(no_binned_date)
      expect(i[:buy_price_min]).to eq(0)
      expect(i[:buy_price_min_date]).to eq(no_binned_date)
      expect(i[:buy_price_max]).to eq(0)
      expect(i[:buy_price_max_date]).to eq(no_binned_date)
    end
  end


end