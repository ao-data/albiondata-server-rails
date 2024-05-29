require 'rails_helper'

RSpec.describe MarketOrderDedupeWorker, :type => :worker do

  it 'calls MarketOrderDedupeService.process' do
    data = { 'foo' => 'bar' }
    opts = { 'baz' => 'qux' }
    s = double
    expect(s).to receive(:process)
    expect(MarketOrderDedupeService).to receive(:new).with(data, 'west', opts).and_return(s)
    subject.perform(data.to_json, 'west', opts.to_json)
  end

end
