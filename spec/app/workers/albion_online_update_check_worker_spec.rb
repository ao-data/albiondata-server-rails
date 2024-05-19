require 'rails_helper'

RSpec.describe AlbionOnlineUpdateCheckWorker, :type => :worker do
  describe '#perform' do
    it 'calls the check method on the service' do
      expect(AlbionOnlineUpdateCheckService).to receive(:check)
      subject.perform
    end
  end
end
