describe GoldDedupeService, type: :service do

  describe ".dedupe" do
    let(:data) { { foo: 'bar' } }

    before do
      ENV['NATS_SEND_DISABLE'] = 'false'
    end

    after do
      ENV['NATS_SEND_DISABLE'] = 'true'
    end

    it "sends the data to the NatsService and GoldProcessorWorker" do
      allow(REDIS).to receive(:get).and_return(nil)

      expect(NatsService).to receive(:send).with('marketorders.deduped', data.to_json)
      expect(GoldProcessorWorker).to receive(:perform_async).with(data.to_json)

      described_class.dedupe(data)
    end

    it "sets a REDIS key with a 10 minute expiry" do
      allow(REDIS).to receive(:get).and_return(nil)

      expect(REDIS).to receive(:set).with("GOLD_RECORD_SHA256:#{Digest::SHA256.hexdigest(data.to_json)}", '1', ex: 600)

      described_class.dedupe(data)
    end

    context "when the REDIS key already exists" do
      before do
        allow(REDIS).to receive(:get).and_return('1')
      end

      it "does not send the data to the NatsService or GoldProcessorWorker" do
        expect(NatsService).not_to receive(:send)
        expect(GoldProcessorWorker).not_to receive(:perform_async)

        described_class.dedupe(data)
      end
    end
  end
end