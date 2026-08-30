require 'rails_helper'

RSpec.describe MarketOrderbookService, :type => :service do
  describe '#get_orderbook' do
    it 'aggregates orders at the same price into a single level' do
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 10, amount: 5, expires: 1.week.from_now)
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 10, amount: 7, expires: 1.week.from_now)

      result = subject.get_orderbook({id: 'T4_BAG', locations: '3005', qualities: '1'})

      expect(result.length).to eq(1)
      expect(result[0][:sell]).to eq([{ price: 10, amount: 12 }])
      expect(result[0][:buy]).to eq([])
    end

    it 'splits offers into sell levels and requests into buy levels' do
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 100, amount: 2, expires: 1.week.from_now)
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'request', price: 90, amount: 3, expires: 1.week.from_now)

      result = subject.get_orderbook({id: 'T4_BAG', locations: '3005', qualities: '1'})

      expect(result[0][:sell]).to eq([{ price: 100, amount: 2 }])
      expect(result[0][:buy]).to eq([{ price: 90, amount: 3 }])
    end

    it 'sorts sell levels cheapest first and buy levels richest first' do
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 300, amount: 1, expires: 1.week.from_now)
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 100, amount: 1, expires: 1.week.from_now)
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'request', price: 200, amount: 1, expires: 1.week.from_now)
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'request', price: 400, amount: 1, expires: 1.week.from_now)

      result = subject.get_orderbook({id: 'T4_BAG', locations: '3005', qualities: '1'})

      expect(result[0][:sell].map { |l| l[:price] }).to eq([100, 300])
      expect(result[0][:buy].map { |l| l[:price] }).to eq([400, 200])
    end

    it 'ignores deleted, expired, non-positive price and non-positive amount orders' do
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 10, amount: 1, expires: 1.week.from_now)
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 10, amount: 1, expires: 1.week.from_now, deleted_at: Time.now)
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 10, amount: 1, expires: 1.day.ago)
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 0, amount: 1, expires: 1.week.from_now)
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 10, amount: 0, expires: 1.week.from_now)

      result = subject.get_orderbook({id: 'T4_BAG', locations: '3005', qualities: '1'})

      expect(result[0][:sell]).to eq([{ price: 10, amount: 1 }])
    end

    it 'returns empty books for unobserved city/quality combinations' do
      result = subject.get_orderbook({id: 'T4_BAG', locations: '3005,7', qualities: '1,2'})

      expect(result.length).to eq(4)
      expect(result).to all(include(sell: [], buy: []))
    end

    it 'supports multiple items and qualities in one request' do
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 10, amount: 1, expires: 1.week.from_now)
      create(:market_order, item_id: 'T5_BAG', location: 3005, quality_level: 2, auction_type: 'request', price: 20, amount: 2, expires: 1.week.from_now)

      result = subject.get_orderbook({id: 'T4_BAG,T5_BAG', locations: '3005', qualities: '1,2'})

      t4_q1 = result.find { |r| r[:item_id] == 'T4_BAG' && r[:quality] == 1 }
      t5_q2 = result.find { |r| r[:item_id] == 'T5_BAG' && r[:quality] == 2 }

      expect(result.length).to eq(4)
      expect(t4_q1[:sell]).to eq([{ price: 10, amount: 1 }])
      expect(t5_q2[:buy]).to eq([{ price: 20, amount: 2 }])
    end
  end
end
