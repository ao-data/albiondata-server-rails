require 'rails_helper'

RSpec.describe MarketHistoryProcessorWorker, :type => :worker do

  it 'calls MarketHistoryProcessorService.process' do
    s = double('service')
    allow(MarketHistoryProcessorService).to receive(:new).and_return(s)

    data = { 'foo' => 'bar' }
    opts = { 'baz' => 'qux' }
    expect(s).to receive(:process).with(data, 'west', opts)
    subject.perform(data.to_json, 'west', opts.to_json)
  end

end
