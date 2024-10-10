require 'rails_helper'

RSpec.describe MarketHistoryExportWorker, :type => :worker do
  it 'calls MarketHistoryExportService.export with defaults' do
    expect(MarketHistoryExportService).to receive(:export).with('west', nil, nil, false)
    subject.perform('west')
  end

  it 'calls MarketHistoryExportService.export with specified parameters' do
    expect(MarketHistoryExportService).to receive(:export).with('west', '2024', '01', false)
    subject.perform('west', '2024', '01', false)
  end

  it 'calls MarketHistoryExportService.export with delete_data set to true' do
    expect(MarketHistoryExportService).to receive(:export).with('west', '2024', '01', true)
    subject.perform('west', '2024', '01', true)
  end
end
