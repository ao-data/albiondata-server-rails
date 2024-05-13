require 'rails_helper'

RSpec.describe MarketOrderProcessorWorker, :type => :worker do

  it 'calls MarketOrderProcessorService.process' do
    data = { 'foo' => 'bar' }
    s = double
    expect(s).to receive(:process)
    expect(MarketOrderProcessorService).to receive(:new).with(data, 'west').and_return(s)
    subject.perform(data.to_json, 'west')
  end

end
