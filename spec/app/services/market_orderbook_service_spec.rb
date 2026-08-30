require 'rails_helper'

RSpec.describe MarketOrderbookService, :type => :service do
  TIMESTAMP_FORMAT = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\z/

  describe '#get_orderbook' do
    it 'aggregates orders at the same price into a single level' do
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 10, amount: 5, expires: 1.week.from_now)
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 10, amount: 7, expires: 1.week.from_now)

      result = subject.get_orderbook({id: 'T4_BAG', locations: '3005', qualities: '1'})

      expect(result.length).to eq(1)
      expect(result[0][:sell]).to contain_exactly(include(price: 10, amount: 12, updated_at: match(TIMESTAMP_FORMAT)))
      expect(result[0][:buy]).to eq([])
    end

    it 'sets each level updated_at to the most recent order at that price' do
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 10, amount: 1, expires: 1.week.from_now, updated_at: DateTime.parse('2024-03-09 09:04:00'))
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 10, amount: 2, expires: 1.week.from_now, updated_at: DateTime.parse('2024-03-09 09:06:00'))

      result = subject.get_orderbook({id: 'T4_BAG', locations: '3005', qualities: '1'})

      expect(result[0][:sell]).to contain_exactly(include(price: 10, amount: 3, updated_at: '2024-03-09T09:06:00'))
    end

    it 'splits offers into sell levels and requests into buy levels' do
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'offer', price: 100, amount: 2, expires: 1.week.from_now)
      create(:market_order, item_id: 'T4_BAG', location: 3005, quality_level: 1, auction_type: 'request', price: 90, amount: 3, expires: 1.week.from_now)

      result = subject.get_orderbook({id: 'T4_BAG', locations: '3005', qualities: '1'})

      expect(result[0][:sell]).to contain_exactly(include(price: 100, amount: 2, updated_at: match(TIMESTAMP_FORMAT)))
      expect(result[0][:buy]).to contain_exactly(include(price: 90, amount: 3, updated_at: match(TIMESTAMP_FORMAT)))
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

      expect(result[0][:sell]).to contain_exactly(include(price: 10, amount: 1, updated_at: match(TIMESTAMP_FORMAT)))
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
      expect(t4_q1[:sell]).to contain_exactly(include(price: 10, amount: 1, updated_at: match(TIMESTAMP_FORMAT)))
      expect(t5_q2[:buy]).to contain_exactly(include(price: 20, amount: 2, updated_at: match(TIMESTAMP_FORMAT)))
    end
  end
end
