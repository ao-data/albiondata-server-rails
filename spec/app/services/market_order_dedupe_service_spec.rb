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
  let (:opts) { { opt1: 'opt1' } }

  let(:subject) { described_class.new(data, 'west', opts) }

  before do
    keys = REDIS['west'].keys('RECORD_SHA256:*')
    REDIS['west'].del(keys)
  end

  describe '#process' do
    before do
      allow(NatsService).to receive(:new).and_return(double(send: nil, close: nil))
    end

    context 'when order has a int LocationId that is not a valid market locationId' do
      before do
        data['Orders'].first['LocationId'] = 0
      end

      after do
        allow(MarketOrderProcessorWorker).to receive(:perform_async)
        subject.process
      end

      it 'it does not call dedupe' do
        expect(subject).not_to receive(:dedupe)
      end

      it 'it does not instantiate NatsService' do
        expect(NatsService).not_to receive(:new)
      end

      it 'it logs that no valid orders were found' do
        expect(IdentifierService).to receive(:add_identifier_event).with(
          opts, 'west', "Received on MarketOrderDedupeService, no valid orders found"
        )
      end
    end    

    context 'when order has a string LocationId that is not a valid market locationId' do
      before do
        data['Orders'].first['LocationId'] = 'pizza'
      end

      after do
        allow(MarketOrderProcessorWorker).to receive(:perform_async)
        subject.process
      end

      it 'it does not call dedupe' do
        expect(subject).not_to receive(:dedupe)
      end

      it 'it does not instantiate NatsService' do
        expect(NatsService).not_to receive(:new)
      end

      it 'it logs that no valid orders were found' do
        expect(IdentifierService).to receive(:add_identifier_event).with(
          opts, 'west', "Received on MarketOrderDedupeService, no valid orders found"
        )
      end
    end
    
    context 'when order has valid non-numeric LocationId' do
      before do
        data['Orders'].first['LocationId'] = '3005'
      end
    
      after do
        allow(MarketOrderProcessorWorker).to receive(:perform_async)
        subject.process
      end
    
      it 'it sends the order to marketorders.ingest with integer LocationId' do
        nats = double
        expect(NatsService).to receive(:new).with('west').and_return(nats)
        expect(nats).to receive(:send).with('marketorders.ingest', anything) do |_, payload|
          orders = JSON.parse(payload)['Orders']
          expect(orders.first['LocationId']).to eq(3005)
        end
        allow(nats).to receive(:send)
        expect(nats).to receive(:close)
      end
    
      it 'it sends the order to marketorders.deduped with integer LocationId' do
        nats = double
        expect(NatsService).to receive(:new).with('west').and_return(nats)
        allow(nats).to receive(:send)
        expect(nats).to receive(:send).with('marketorders.deduped', anything) do |_, payload|
          order = JSON.parse(payload)
          expect(order['LocationId']).to eq(3005)
        end
        expect(nats).to receive(:close)
      end
    
      it 'it sends the order to marketorders.deduped.bulk with integer LocationId' do
        nats = double
        expect(NatsService).to receive(:new).with('west').and_return(nats)
        allow(nats).to receive(:send)
        expect(nats).to receive(:send).with('marketorders.deduped.bulk', anything) do |_, payload|
          orders = JSON.parse(payload)
          expect(orders.first['LocationId']).to eq(3005)
        end
        expect(nats).to receive(:close)
      end
    end
    
    context 'when order has valid numeric LocationId' do
      before do
        data['Orders'].first['LocationId'] = 3005
      end
    
      after do
        allow(MarketOrderProcessorWorker).to receive(:perform_async)
        subject.process
      end
    
      it 'it sends the order to marketorders.ingest with integer LocationId' do
        nats = double
        expect(NatsService).to receive(:new).with('west').and_return(nats)
        expect(nats).to receive(:send).with('marketorders.ingest', anything) do |_, payload|
          orders = JSON.parse(payload)['Orders']
          expect(orders.first['LocationId']).to eq(3005)
        end
        allow(nats).to receive(:send)
        expect(nats).to receive(:close)
      end
    
      it 'it sends the order to marketorders.deduped with integer LocationId' do
        nats = double
        expect(NatsService).to receive(:new).with('west').and_return(nats)
        allow(nats).to receive(:send)
        expect(nats).to receive(:send).with('marketorders.deduped', anything) do |_, payload|
          order = JSON.parse(payload)
          expect(order['LocationId']).to eq(3005)
        end
        expect(nats).to receive(:close)
      end
    
      it 'it sends the order to marketorders.deduped.bulk with integer LocationId' do
        nats = double
        expect(NatsService).to receive(:new).with('west').and_return(nats)
        allow(nats).to receive(:send)
        expect(nats).to receive(:send).with('marketorders.deduped.bulk', anything) do |_, payload|
          orders = JSON.parse(payload)
          expect(orders.first['LocationId']).to eq(3005)
        end
        expect(nats).to receive(:close)
      end
    end
    
    context 'when order has valid non-numeric portal LocationId' do
      before do
        data['Orders'].first['LocationId'] = '2301'
      end
    
      after do
        allow(MarketOrderProcessorWorker).to receive(:perform_async)
        subject.process
      end
    
      it 'it sends the order to marketorders.ingest with integer LocationId' do
        nats = double
        expect(NatsService).to receive(:new).with('west').and_return(nats)
        expect(nats).to receive(:send).with('marketorders.ingest', anything) do |_, payload|
          orders = JSON.parse(payload)['Orders']
          expect(orders.first['LocationId']).to eq(2004)
        end
        allow(nats).to receive(:send)
        expect(nats).to receive(:close)
      end
    
      it 'it sends the order to marketorders.deduped with integer LocationId' do
        nats = double
        expect(NatsService).to receive(:new).with('west').and_return(nats)
        allow(nats).to receive(:send)
        expect(nats).to receive(:send).with('marketorders.deduped', anything) do |_, payload|
          order = JSON.parse(payload)
          expect(order['LocationId']).to eq(2004)
        end
        expect(nats).to receive(:close)
      end
    
      it 'it sends the order to marketorders.deduped.bulk with integer LocationId' do
        nats = double
        expect(NatsService).to receive(:new).with('west').and_return(nats)
        allow(nats).to receive(:send)
        expect(nats).to receive(:send).with('marketorders.deduped.bulk', anything) do |_, payload|
          orders = JSON.parse(payload)
          expect(orders.first['LocationId']).to eq(2004)
        end
        expect(nats).to receive(:close)
      end
    end
    
    context 'when order has valid numeric portal LocationId' do
      before do
        data['Orders'].first['LocationId'] = 2301
      end
    
      after do
        allow(MarketOrderProcessorWorker).to receive(:perform_async)
        subject.process
      end
    
      it 'it sends the order to marketorders.ingest with integer LocationId' do
        nats = double
        expect(NatsService).to receive(:new).with('west').and_return(nats)
        expect(nats).to receive(:send).with('marketorders.ingest', anything) do |_, payload|
          orders = JSON.parse(payload)['Orders']
          expect(orders.first['LocationId']).to eq(2004)
        end
        allow(nats).to receive(:send)
        expect(nats).to receive(:close)
      end
    
      it 'it sends the order to marketorders.deduped with integer LocationId' do
        nats = double
        expect(NatsService).to receive(:new).with('west').and_return(nats)
        allow(nats).to receive(:send)
        expect(nats).to receive(:send).with('marketorders.deduped', anything) do |_, payload|
          order = JSON.parse(payload)
          expect(order['LocationId']).to eq(2004)
        end
        expect(nats).to receive(:close)
      end
    
      it 'it sends the order to marketorders.deduped.bulk with integer LocationId' do
        nats = double
        expect(NatsService).to receive(:new).with('west').and_return(nats)
        allow(nats).to receive(:send)
        expect(nats).to receive(:send).with('marketorders.deduped.bulk', anything) do |_, payload|
          orders = JSON.parse(payload)
          expect(orders.first['LocationId']).to eq(2004)
        end
        expect(nats).to receive(:close)
      end
    end

    context 'when there are deduped records' do
      before do
        allow(subject).to receive(:dedupe).and_return([{ 'UnitPriceSilver' => 249 }])

        allow(NatsService).to receive(:new).and_return(double(send: nil, close: nil))
      end

      it 'it sends deduped records to nats' do
        nats = double
        expect(NatsService).to receive(:new).with('west').and_return(nats)
        expect(nats).to receive(:send).with('marketorders.ingest', data.to_json)
        expect(nats).to receive(:send).with('marketorders.deduped', subject.dedupe.first.to_json)
        expect(nats).to receive(:send).with('marketorders.deduped.bulk', [subject.dedupe.first].to_json)
        expect(nats).to receive(:close)
        subject.process
      end

      it 'it sends deduped records to MarketOrderProcessorWorker' do
        expect(MarketOrderProcessorWorker).to receive(:perform_async).with(subject.dedupe.to_json, 'west', opts.to_json)
        subject.process
      end
    end

    context 'when there are no deduped records' do
      before do
        allow(subject).to receive(:dedupe).and_return([])
      end

      it 'it does not send any records to MarketOrderProcessorWorker' do
        expect(MarketOrderProcessorWorker).not_to receive(:perform_async)
        subject.process
      end
    end

    it 'sends logs' do
      expected_log = {
        class: 'MarketOrderDedupeService',
        method: 'process',
        data: data,
        server_id: 'west',
        opts: opts,
        deduped_recprds: [ fake: 'data']
      }

      allow(subject).to receive(:dedupe).and_return([ fake: 'data'])
      expect(Sidekiq.logger).to receive(:info).with(expected_log.to_json)
      subject.process
    end
  end

  describe '#dedupe' do
    context 'when order is not a duplicate' do
      it 'it adjusts unit price silver' do
        result = subject.dedupe
        expect(result.first['UnitPriceSilver']).to eq(249)
      end

      it 'merges portals to parent city' do
        data['Orders'].first['LocationId'] = 301
        result = subject.dedupe
        expect(result.first['LocationId']).to eq(7)
      end

      it 'does not merge non-portal locations' do
        data['Orders'].first['LocationId'] = 3005
        result = subject.dedupe
        expect(result.first['LocationId']).to eq(3005)
      end

      it 'sends an activesupport notification' do
        expected_payload = { server_id: 'west', locations: {1002 => { duplicates: 0, non_duplicates: 1 }} }
        expect(ActiveSupport::Notifications).to receive(:instrument).with('metrics.market_order_dedupe_service', expected_payload)
        subject.dedupe
      end
    end

    context 'when order is a duplicate' do
      before do
        allow(REDIS['west']).to receive(:get).and_return('1')
      end

      it 'it does not add order to deduped list' do
        result = subject.dedupe
        expect(result).to be_empty
      end

      it 'sends an activesupport notification' do
        expected_payload = { server_id: 'west', locations: {1002 => { duplicates: 1, non_duplicates: 0 }} }
        expect(ActiveSupport::Notifications).to receive(:instrument).with('metrics.market_order_dedupe_service', expected_payload)
        subject.dedupe
      end
    end

    it 'it sends logs' do
      expected_log = {
        class: 'MarketOrderDedupeService',
        method: 'dedupe',
        opts: opts,
        redis_duplicates: 0
      }

      expect(Sidekiq.logger).to receive(:info).with(expected_log.to_json)
      subject.dedupe
    end
  end
end
