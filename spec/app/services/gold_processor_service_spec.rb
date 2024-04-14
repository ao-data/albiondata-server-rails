describe GoldProcessorService, type: :service do

  describe '.process' do
    let(:data) { { 'Prices' => [1, 2, 3], 'Timestamps' => [638486496000000000, 638486460000000000, 638486424000000000] } }

    before do
      GoldPrice.destroy_all
    end

    it 'creates gold prices' do
      expect { described_class.process(data) }.to change { GoldPrice.count }.by(3)
    end

    it 'creates gold prices with correct attributes' do
      described_class.process(data)

      expect(GoldPrice.first.price).to eq(1)
      expect(GoldPrice.first.timestamp).to eq(Time.at((638486496000000000 - 621355968000000000)/10000000))
    end
  end
end