require 'rails_helper'

RSpec.describe ActiveSupportNotificationWorker, :type => :worker do
  it 'calls ActiveSupportNotificationService.process' do
    name = "metric_name"
    payload = { 'foo' => 'bar' }
    expect(ActiveSupportNotificationService).to receive(:process).with(name, payload)
    subject.perform(name, payload.to_json)
  end
end
