require 'rails_helper'

RSpec.describe GoldDedupeWorker, :type => :worker do

  it 'calls GoldDedupeService.dedupe' do
    data = { 'foo' => 'bar' }
    expect(GoldDedupeService).to receive(:dedupe).with(data, 'west')
    subject.perform(data.to_json, 'west')
  end

end
