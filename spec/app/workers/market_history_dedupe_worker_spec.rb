require 'rails_helper'

RSpec.describe MarketHistoryDedupeWorker, :type => :worker do

  it 'calls MarketHistoryDedupeService.dedupe' do
    data = { 'foo' => 'bar' }
    expect(MarketHistoryDedupeService).to receive(:dedupe).with(data, 'west')
    subject.perform(data.to_json, 'west')
  end
end
