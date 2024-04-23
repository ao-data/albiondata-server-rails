require 'rails_helper'

RSpec.describe MarketHistoryProcessorWorker, :type => :worker do

  it 'calls MarketHistoryProcessorService.process' do
    data = { 'foo' => 'bar' }
    expect(MarketHistoryProcessorService).to receive(:process).with(data, 'west')
    subject.perform(data.to_json, 'west')
  end

end
