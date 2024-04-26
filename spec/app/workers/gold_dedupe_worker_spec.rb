require 'rails_helper'

RSpec.describe GoldDedupeWorker, :type => :worker do

  it 'calls GoldDedupeService.dedupe' do
    data = { 'foo' => 'bar' }
    s = double
    expect(s).to receive(:dedupe).with(data, 'west')

    allow(GoldDedupeService).to receive(:new).and_return(s)
    subject.perform(data.to_json, 'west')
  end

end
