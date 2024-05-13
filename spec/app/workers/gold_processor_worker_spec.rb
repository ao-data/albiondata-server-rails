require 'rails_helper'

RSpec.describe GoldProcessorWorker, :type => :worker do

  it 'calls GoldProcessorService.process' do
    s = double
    allow(GoldProcessorService).to receive(:new).and_return(s)

    data = { 'foo' => 'bar' }
    expect(s).to receive(:process).with(data, 'west')
    subject.perform(data.to_json, 'west')
  end

end
