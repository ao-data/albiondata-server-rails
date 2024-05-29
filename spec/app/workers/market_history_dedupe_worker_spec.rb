require 'rails_helper'

RSpec.describe MarketHistoryDedupeWorker, :type => :worker do

  it 'calls MarketHistoryDedupeService.dedupe' do
    s = double
    allow(MarketHistoryDedupeService).to receive(:new).and_return(s)

    data = { 'foo' => 'bar' }
    opts = { 'baz' => 'qux' }
    expect(s).to receive(:dedupe).with(data, 'west', opts)
    subject.perform(data.to_json, 'west', opts.to_json)
  end
end
