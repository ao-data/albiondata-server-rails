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
end
