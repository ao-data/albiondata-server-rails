require 'rails_helper'

RSpec.describe KillEventPollWorker, type: :worker do
  it 'calls GameinfoService.poll_events' do
    s = double
    allow(GameinfoService).to receive(:new).with('west').and_return(s)
    expect(s).to receive(:poll_events)

    subject.perform('west')
  end

  it 'runs on the gameinfo queue without retries' do
    expect(described_class.get_sidekiq_options).to include('queue' => :gameinfo, 'retry' => false)
  end
end
