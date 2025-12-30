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

    it 'only updates price if it is different' do
      timestamp = 638486496000000000
      initial_price = 100
      timestamp_time = Time.at((timestamp - 621355968000000000)/10000000)
      
      # Create initial record
      gold_price = GoldPrice.create(
        price: initial_price,
        timestamp: timestamp_time
      )
      
      # Process with same price - should not call update
      same_price_data = { 'Prices' => [initial_price], 'Timestamps' => [timestamp] }
      update_spy = allow_any_instance_of(GoldPrice).to receive(:update).and_call_original
      subject.process(same_price_data, 'west', opts)
      
      # Verify update was not called
      expect(update_spy).not_to have_received(:update)
      
      # Reload and verify price hasn't changed
      gold_price.reload
      expect(gold_price.price).to eq(initial_price)
      
      # Process with different price - should call update
      new_price = 200
      different_price_data = { 'Prices' => [new_price], 'Timestamps' => [timestamp] }
      # Create a new spy for the second call
      update_spy2 = allow_any_instance_of(GoldPrice).to receive(:update).and_call_original
      subject.process(different_price_data, 'west', opts)
      
      # Verify update was called
      expect(update_spy2).to have_received(:update).with(price: new_price)
      
      # Reload and verify price was updated
      gold_price.reload
      expect(gold_price.price).to eq(new_price)
    end
  end
end