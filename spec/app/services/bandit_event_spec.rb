describe BanditEventService, type: :service do

  describe '.process' do
    let(:data) { { 'EventTime' => 638997538711438026 } }
    let(:opts) { { 'foo' => 'bar' } }

    it 'sends a log message' do
      expected_log =  { class: 'BanditEventService', method: 'process', data: data, server_id: 'west', opts: opts }.to_json
      expect(Sidekiq.logger).to receive(:info).with(expected_log)
      subject.process(data, 'west', opts)
    end
  end
end
