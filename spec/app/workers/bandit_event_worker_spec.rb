require 'rails_helper'

RSpec.describe BanditEventWorker, :type => :worker do

  it 'calls BanditEventService.process' do
    data = { 'foo' => 'bar' }
    opts = { 'baz' => 'qux' }

    s = double
    allow(BanditEventService).to receive(:new).and_return(s)
    expect(s).to receive(:process).with(data, 'west', opts)

    subject.perform(data.to_json, 'west', opts.to_json)
  end

end
