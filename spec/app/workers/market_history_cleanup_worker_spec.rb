require 'rails_helper'

RSpec.describe MarketHistoryCleanupWorker, :type => :worker do

  it 'calls MarketHistory.purge_old_data' do
    expect(MarketHistory).to receive(:purge_old_data)
    subject.perform
  end

end
