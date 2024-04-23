describe GoldDedupeService, type: :service do

  describe ".dedupe" do
    let(:data) { { foo: 'bar' } }
    let(:server_id) { 'west' }

    before do
      allow(NatsService).to receive(:send)
      ENV['NATS_SEND_DISABLE'] = 'false'
    end

    after do
      ENV['NATS_SEND_DISABLE'] = 'true'
    end

    it "sends the data to the NatsService and GoldProcessorWorker" do
      allow(REDIS).to receive(:get).and_return(nil)

      nats = double
      allow(nats).to receive(:send).with('marketorders.deduped', data.to_json)
      allow(nats).to receive(:close)
      allow(NatsService).to receive(:new).and_return(nats)

      expect(GoldProcessorWorker).to receive(:perform_async).with(data.to_json, server_id)

      described_class.dedupe(data, server_id)
    end

    it "sets a REDIS key with a 10 minute expiry" do
      allow(REDIS).to receive(:get).and_return(nil)

      expect(REDIS).to receive(:set).with("GOLD_RECORD_SHA256:#{Digest::SHA256.hexdigest(data.to_json)}", '1', ex: 600)

      described_class.dedupe(data, server_id)
    end

    context "when the REDIS key already exists" do
      before do
        allow(REDIS).to receive(:get).and_return('1')
      end

      it "does not send the data to the NatsService or GoldProcessorWorker" do
        expect(NatsService).to_not receive(:new)
        expect(GoldProcessorWorker).not_to receive(:perform_async)

        described_class.dedupe(data, server_id)
      end
    end
  end
end
