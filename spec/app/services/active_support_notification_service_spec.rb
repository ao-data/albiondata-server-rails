require 'rails_helper'

RSpec.describe ActiveSupportNotificationService, :type => :worker do
  let (:payload) { { 'foo' => 'bar' } }

  before(:each) do
    ENV['METRICS_ENABLED'] = 'true'
  end

  context 'when metrics are disabled' do
    it 'does not process' do
      ENV['METRICS_ENABLED'] = 'false'
      name = "metrics.market_order_dedupe_service"
      expect(described_class).to_not receive(:market_order_dedupe_service).with(payload)
      described_class.process(name, payload)
    end
  end

  context 'name is metrics.market_order_dedupe_service' do
    it 'calls market_order_dedupe_service' do
      name = "metrics.market_order_dedupe_service"
      expect(described_class).to receive(:market_order_dedupe_service).with(payload)
      described_class.process(name, payload)
    end
  end

  context 'name is metrics.market_history_dedupe_service' do
    it 'calls market_history_dedupe_service' do
      name = "metrics.market_history_dedupe_service"
      expect(described_class).to receive(:market_history_dedupe_service).with(payload)
      described_class.process(name, payload)
    end
  end

  context 'name is metrics.gold_dedupe_service' do
    it 'calls gold_dedupe_service' do
      name = "metrics.gold_dedupe_service"
      expect(described_class).to receive(:gold_dedupe_service).with(payload)
      described_class.process(name, payload)
    end
  end

  context 'name is unhandled' do
    it 'logs a warning' do
      name = "unhandled"
      expect(Rails.logger).to receive(:warn).with("ActiveSupportNotificationService: Unhandled event: #{name}")
      described_class.process(name, payload)
    end
  end
end
