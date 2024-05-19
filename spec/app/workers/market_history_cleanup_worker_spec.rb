require 'rails_helper'

RSpec.describe MarketHistoryCleanupWorker, :type => :worker do

  it 'calls MarketHistory.purge_weekly_data' do
    expect(MarketHistory).to receive(:purge_weekly_data)
    subject.perform('west')
  end

  it 'uses the correct database' do
    expect(Multidb).to receive(:use).with(:east).and_call_original
    subject.perform('east')
  end

  it 'calls MarketHistory.purge_old_data with the correct parameters' do
    expect(MarketHistory).to receive(:purge_older_data)
    subject.perform('west', false)
  end
end
