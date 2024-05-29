describe MarketOrderProcessorService, type: :service do
  let(:order1) { { 'Id' => 12226808117, 'ItemTypeId' => 'T1_MEAL_SEAWEEDSALAD', 'ItemGroupTypeId' => 'T1_MEAL_SEAWEEDSALAD', 'LocationId' => 1002, 'QualityLevel' => 1, 'EnchantmentLevel' => 0, 'UnitPriceSilver' => 2490000, 'Amount' => 15, 'AuctionType' => 'offer', 'Expires' => '2024-04-15T00:24:27.605927' } }
  let(:order2) { { 'Id' => 12226808118, 'ItemTypeId' => 'T1_MEAL_SEAWEEDSALAD', 'ItemGroupTypeId' => 'T1_MEAL_SEAWEEDSALAD', 'LocationId' => 1002, 'QualityLevel' => 1, 'EnchantmentLevel' => 0, 'UnitPriceSilver' => 2490000, 'Amount' => 15, 'AuctionType' => 'offer', 'Expires' => '2024-04-15T00:24:27.605927' } }
  let(:orders) { [order1, order2] }
  let(:opts) { { opt1: 'opt1' } }
  let(:subject) { described_class.new(orders, 'west', opts) }

  before do
    REDIS['west'].flushall
    MarketOrder.delete_all
  end

  describe '#process' do
    let(:new_order) { { 'Id' => 12226808119, 'ItemTypeId' => 'T1_MEAL_SEAWEEDSALAD', 'ItemGroupTypeId' => 'T1_MEAL_SEAWEEDSALAD', 'LocationId' => 1002, 'QualityLevel' => 1, 'EnchantmentLevel' => 0, 'UnitPriceSilver' => 2490000, 'Amount' => 15, 'AuctionType' => 'offer', 'Expires' => '2024-04-15T00:24:27.605927' } }

    it 'adds 1 new record' do
      subject = described_class.new([new_order], 'west', opts)
      expect { subject.process }.to change { MarketOrder.count }.by(1)
    end

    it 'adds 2 new records' do
      subject = described_class.new(orders, 'west', opts)
      expect { subject.process }.to change { MarketOrder.count }.by(2)
    end

    it 'does not add duplicate records' do
      subject = described_class.new(orders, 'west', opts)
      subject.process
      expect { subject.process }.to change { MarketOrder.count }.by(0)
    end

    it 'updates existing records with changed data' do
      subject = described_class.new(orders, 'west', opts)
      subject.process
      order1['UnitPriceSilver'] = 1000000
      expect { subject.process }.to change { MarketOrder.find_by(albion_id: 12226808117).price }.from(2490000).to(1000000)
    end

    it 'updates existing records with only changed updated_at' do
      subject = described_class.new(orders, 'west', opts)
      subject.process
      old_epoch = DateTime.now.to_i
      Timecop.freeze(Time.now + 1.day)
      expect { subject.process }.to change { MarketOrder.find_by(albion_id: 12226808117).updated_at.to_i }.from(old_epoch).to(DateTime.now.to_i)
    end

    it 'calls MarketOrder.insert_all' do
      subject = described_class.new(orders, 'west', opts)
      expect(MarketOrder).to receive(:upsert_all)
      subject.process
    end

    it 'has the correct data' do
      subject = described_class.new(orders, 'west', opts)
      subject.process
      r = MarketOrder.find_by(albion_id: 12226808117)
      expect(r.item_id).to eq('T1_MEAL_SEAWEEDSALAD')
      expect(r.quality_level).to eq(1)
      expect(r.enchantment_level).to eq(0)
      expect(r.price).to eq(2490000)
      expect(r.initial_amount).to eq(15)
      expect(r.amount).to eq(15)
      expect(r.auction_type).to eq('offer')
      expect(r.expires.to_i).to eq(DateTime.parse('2024-04-15T00:24:27.605927').to_i)
      expect(r.location).to eq(1002)
    end

    it 'sends logs' do
      Timecop.freeze
      subject = described_class.new([order1], 'west', opts)

      expected_records = [
        {
          albion_id: 12226808117,
          item_id: 'T1_MEAL_SEAWEEDSALAD',
          quality_level: 1,
          enchantment_level: 0,
          price: 2490000,
          initial_amount: 15,
          amount: 15,
          auction_type: 'offer',
          expires: DateTime.parse('2024-04-15T00:24:27.605927'),
          location: 1002,
          updated_at: DateTime.now
        }
      ]

      expected_log = {
        class: 'MarketOrderProcessorService',
        method: 'process',
        data: [order1],
        server_id: 'west',
        opts: opts,
        record_data: expected_records
      }

      expect(Sidekiq.logger).to receive(:info).with(expected_log.to_json)
      subject.process
    end
  end
end
