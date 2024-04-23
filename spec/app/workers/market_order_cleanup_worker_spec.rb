require 'rails_helper'

RSpec.describe MarketOrderCleanupWorker, :type => :worker do

  it 'calls MarketOrder.purge_old_data' do
    expect(MarketOrder).to receive(:purge_old_data)
    subject.perform('west')
  end

end
