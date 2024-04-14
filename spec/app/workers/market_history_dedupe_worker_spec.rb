require 'rails_helper'

RSpec.describe MarketHistoryDedupeWorker, :type => :worker do

  it 'calls MarketHistoryDedupeService.dedupe' do
    data = { 'foo' => 'bar' }
    expect(MarketHistoryDedupeService).to receive(:dedupe).with(data)
    subject.perform(data.to_json)
  end
end
