describe GoldDedupeService, type: :service do

  describe ".dedupe" do
    let(:data) { { foo: 'bar' } }
    let(:server_id) { 'west' }
    let(:opts) { { baz: 'qux' } }

    before do
      allow(NatsService).to receive(:send)
      ENV['NATS_SEND_DISABLE'] = 'false'
    end

    after do
      ENV['NATS_SEND_DISABLE'] = 'true'
    end

    it "sends the data to the NatsService and GoldProcessorWorker" do
      allow(REDIS['west']).to receive(:get).and_return(nil)
      allow(REDIS['west']).to receive(:set).and_return(nil)

      nats = double
      expect(nats).to receive(:send).with('goldprices.ingest', data.to_json)
      expect(nats).to receive(:send).with('goldprices.deduped', data.to_json)
      allow(nats).to receive(:close)
      allow(NatsService).to receive(:new).with('west').and_return(nats)

      expect(GoldProcessorWorker).to receive(:perform_async).with(data.to_json, server_id, opts.to_json)

      subject.dedupe(data, server_id, opts)
    end

    it "sets a REDIS key with a 10 minute expiry" do
      nats = double
      allow(nats).to receive(:send)
      allow(nats).to receive(:close)
      allow(NatsService).to receive(:new).and_return(nats)

      allow(REDIS['west']).to receive(:get).and_return(nil)
      expect(REDIS['west']).to receive(:set).with("GOLD_RECORD_SHA256:#{Digest::SHA256.hexdigest(data.to_json)}", '1', ex: 600)

      subject.dedupe(data, server_id, opts)
    end

    describe 'logging' do
      it 'logs a message when the data is not a duplicate' do
        allow(REDIS['west']).to receive(:get).and_return(nil)
        expected_log = { class: 'GoldDedupeService', method: 'dedupe', data: data, server_id: server_id,
                         opts: opts, message: 'data not duplicate' }.to_json
        expect(Sidekiq.logger).to receive(:info).with(expected_log)
        subject.dedupe(data, server_id, opts)
      end

      it 'logs a message when the data is a duplicate' do
        allow(REDIS['west']).to receive(:get).and_return('1')
        expected_log = { class: 'GoldDedupeService', method: 'dedupe', data: data, server_id: server_id,
                         opts: opts, message: 'data duplicate' }.to_json
        expect(Sidekiq.logger).to receive(:info).with(expected_log)
        subject.dedupe(data, server_id, opts)
      end
    end

    describe 'metrics' do
      it 'sends an activesupport notification with duplicate false' do
        allow(REDIS['west']).to receive(:get).and_return(nil)
        expected_payload = { server_id: 'west', duplicate: false }
        expect(ActiveSupport::Notifications).to receive(:instrument).with('metrics.gold_dedupe_service', expected_payload)
        subject.dedupe(data, server_id, opts)
      end

      it 'sends an activesupport notification with duplicate true' do
        allow(REDIS['west']).to receive(:get).and_return('1')
        expected_payload = { server_id: 'west', duplicate: true }
        expect(ActiveSupport::Notifications).to receive(:instrument).with('metrics.gold_dedupe_service', expected_payload)
        subject.dedupe(data, server_id, opts)
      end
    end

    context "when the REDIS key already exists" do
      before do
        allow(REDIS['west']).to receive(:get).and_return('1')
      end

      it "does not send the data to the GoldProcessorWorker" do
        expect(GoldProcessorWorker).not_to receive(:send)

        subject.dedupe(data, server_id, opts)
      end
    end
  end
end
