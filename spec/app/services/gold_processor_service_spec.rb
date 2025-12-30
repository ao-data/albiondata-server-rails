describe GoldProcessorService, type: :service do

  describe '.process' do
    let(:data) { { 'Prices' => [1, 2, 3], 'Timestamps' => [638486496000000000, 638486460000000000, 638486424000000000] } }
    let(:opts) { { 'foo' => 'bar' } }

    before do
      Multidb.use(:west)
      GoldPrice.destroy_all
    end

    it 'creates gold prices' do
      expect { subject.process(data, 'west', opts) }.to change { GoldPrice.count }.by(3)
    end

    it 'creates gold prices with correct attributes' do
      subject.process(data, 'west', opts)

      expect(GoldPrice.first.price).to eq(1)
      expect(GoldPrice.first.timestamp).to eq(Time.at((638486496000000000 - 621355968000000000)/10000000))
    end

    it 'uses the correct database' do
      expect(Multidb).to receive(:use).with(:east).and_call_original
      subject.process(data, 'east', opts)
    end

    it 'sends a log message' do
      expected_log = { class: 'GoldProcessorService', method: 'process', data: data, server_id: 'west', opts: opts }.to_json
      expect(Sidekiq.logger).to receive(:info).with(expected_log)
      subject.process(data, 'west', opts)
    end
  end
end