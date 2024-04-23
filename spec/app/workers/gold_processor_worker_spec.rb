require 'rails_helper'

RSpec.describe GoldProcessorWorker, :type => :worker do

  it 'calls GoldProcessorService.process' do
    data = { 'foo' => 'bar' }
    expect(GoldProcessorService).to receive(:process).with(data, 'west')
    subject.perform(data.to_json, 'west')
  end

end
