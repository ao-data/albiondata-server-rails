require 'rails_helper'

RSpec.describe MarketOrderDedupeService, type: :subject do
  let(:data) do
    {
      'Orders' => [
        {
          'Id' => 12226808117,
          'ItemTypeId' => 'T1_MEAL_SEAWEEDSALAD',
          'ItemGroupTypeId' => 'T1_MEAL_SEAWEEDSALAD',
          'LocationId' => 1002,
          'QualityLevel' => 1,
          'EnchantmentLevel' => 0,
          'UnitPriceSilver' => 2490000,
          'Amount' => 15,
          'AuctionType' => 'offer',
          'Expires' => '2024-04-15T00:24:27.605927'
        }
      ]
    }
  end

  let(:subject) { described_class.new(data, 'west') }

  before do
    allow(REDIS['west']).to receive(:get).and_return(nil)
    allow(REDIS['west']).to receive(:set)
  end

  describe '#process' do
    before do
      allow(NatsService).to receive(:new).and_return(double(send: nil, close: nil))
    end

    context 'when there are deduped records' do
      before do
        allow(subject).to receive(:dedupe).and_return([{ 'UnitPriceSilver' => 249 }])

        allow(NatsService).to receive(:new).and_return(double(send: nil, close: nil))
      end

      it 'sends deduped records to nats' do
        nats = double
        expect(NatsService).to receive(:new).with('west').and_return(nats)
        expect(nats).to receive(:send).with('marketorders.ingest', data.to_json)
        expect(nats).to receive(:send).with('marketorders.deduped', subject.dedupe.first.to_json)
        expect(nats).to receive(:send).with('marketorders.deduped.bulk', [subject.dedupe.first].to_json)
        expect(nats).to receive(:close)
        subject.process
      end

      it 'sends deduped records to MarketOrderProcessorWorker' do
        expect(MarketOrderProcessorWorker).to receive(:perform_async).with(subject.dedupe.to_json, 'west')
        subject.process
      end
    end

    context 'when there are no deduped records' do
      before do
        allow(subject).to receive(:dedupe).and_return([])
      end

      it 'does not send any records to MarketOrderProcessorWorker' do
        expect(MarketOrderProcessorWorker).not_to receive(:perform_async)
        subject.process
      end
    end
  end

  describe '#dedupe' do
    context 'when order is not a duplicate' do
      it 'adjusts unit price silver' do
        result = subject.dedupe
        expect(result.first['UnitPriceSilver']).to eq(249)
      end

      it 'merges portals to parent city' do
        data['Orders'].first['LocationId'] = 301
        result = subject.dedupe
        expect(result.first['LocationId']).to eq(7)
      end

      it 'does not merge non-portal locations' do
        data['Orders'].first['LocationId'] = 5000
        result = subject.dedupe
        expect(result.first['LocationId']).to eq(5000)
      end
    end

    context 'when order is a duplicate' do
      before do
        allow(REDIS['west']).to receive(:get).and_return('1')
      end

      it 'does not add order to deduped list' do
        result = subject.dedupe
        expect(result).to be_empty
      end
    end

    context 'when order has LocationId equal to 0' do
      before do
        data['Orders'].first['LocationId'] = 0
      end

      it 'skips the order' do
        result = subject.dedupe
        expect(result).to be_empty
      end
    end

    context 'when order has non-numeric LocationId' do
      before do
        data['Orders'].first['LocationId'] = '3005'
      end

      it 'skips the order' do
        result = subject.dedupe
        expect(result).to be_empty
      end
    end

  end
end
