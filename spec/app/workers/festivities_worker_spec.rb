require 'rails_helper'

RSpec.describe FestivitiesWorker, type: :worker do
  it 'calls FestivitiesService.process' do
    data = { 'Events' => [] }
    opts = { 'client_ip' => '1.1.1.1' }
    service = instance_double(FestivitiesService)

    allow(FestivitiesService).to receive(:new).and_return(service)
    expect(service).to receive(:process).with(data, 'west', opts)

    subject.perform(data.to_json, 'west', opts.to_json)
  end
end
