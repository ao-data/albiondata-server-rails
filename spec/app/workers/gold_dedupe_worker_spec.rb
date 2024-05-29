require 'rails_helper'

RSpec.describe GoldDedupeWorker, :type => :worker do

  it 'calls GoldDedupeService.dedupe' do
    data = { 'foo' => 'bar' }
    opts = { 'baz' => 'qux' }
    s = double
    expect(s).to receive(:dedupe).with(data, 'west', opts)

    allow(GoldDedupeService).to receive(:new).and_return(s)
    subject.perform(data.to_json, 'west', opts.to_json)
  end

end
