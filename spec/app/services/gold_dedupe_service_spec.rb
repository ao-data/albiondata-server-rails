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
      allow(REDIS['west']).to receive(:get).and_return(nil)
      allow(REDIS['west']).to receive(:set).and_return(nil)

      nats = double
      expect(nats).to receive(:send).with('goldprices.ingest', data.to_json)
      expect(nats).to receive(:send).with('goldprices.deduped', data.to_json)
      allow(nats).to receive(:close)
      allow(NatsService).to receive(:new).with('west').and_return(nats)

      expect(GoldProcessorWorker).to receive(:perform_async).with(data.to_json, server_id)

      subject.dedupe(data, server_id)
    end

    it "sets a REDIS key with a 10 minute expiry" do
      nats = double
      allow(nats).to receive(:send)
      allow(nats).to receive(:close)
      allow(NatsService).to receive(:new).and_return(nats)

      allow(REDIS['west']).to receive(:get).and_return(nil)
      expect(REDIS['west']).to receive(:set).with("GOLD_RECORD_SHA256:#{Digest::SHA256.hexdigest(data.to_json)}", '1', ex: 600)

      subject.dedupe(data, server_id)
    end

    context "when the REDIS key already exists" do
      before do
        allow(REDIS['west']).to receive(:get).and_return('1')
      end

      it "does not send the data to the GoldProcessorWorker" do
        expect(GoldProcessorWorker).not_to receive(:send)

        subject.dedupe(data, server_id)
      end
    end
  end
end
