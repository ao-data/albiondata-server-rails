require 'rails_helper'

RSpec.describe MarketHistoryExportWorker, :type => :worker do
  it 'calls MarketHistoryExportService.export with defaults' do
    expect(MarketHistoryExportService).to receive(:export).with('west', nil, nil)
    subject.perform('west')
  end

  it 'calls MarketHistoryExportService.export with specified parameters' do
    expect(MarketHistoryExportService).to receive(:export).with('west', '2024', '01')
    subject.perform('west', '2024', '01')
  end

  it 'deletes data if delete_data is true' do
    Timecop.freeze(Time.new(2024, 1, 1)) do
      Multidb.use(:west) do
        create(:market_history, timestamp: Time.new(2023, 12, 1))
        create(:market_history, timestamp: Time.new(2024, 1, 1))
        create(:market_history, timestamp: Time.new(2024, 2, 1))
      end
      expect(MarketHistoryExportService).to receive(:export).with('west', '2024', '01')
      subject.perform('west', '2024', '01', true)
      Multidb.use(:west) do
        expect(MarketHistory.count).to eq(2)
        expect(MarketHistory.where("timestamp between '2024-01-01' and '2024-01-31'").count).to eq(0)
      end
    end
  end
end
