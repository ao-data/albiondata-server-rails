describe MarketOrderProcessorService, type: :service do
  let(:order1) { { 'Id' => 12226808117, 'ItemTypeId' => 'T1_MEAL_SEAWEEDSALAD', 'ItemGroupTypeId' => 'T1_MEAL_SEAWEEDSALAD', 'LocationId' => 1002, 'QualityLevel' => 1, 'EnchantmentLevel' => 0, 'UnitPriceSilver' => 2490000, 'Amount' => 15, 'AuctionType' => 'offer', 'Expires' => '2024-04-15T00:24:27.605927' } }
  let(:order2) { { 'Id' => 12226808118, 'ItemTypeId' => 'T1_MEAL_SEAWEEDSALAD', 'ItemGroupTypeId' => 'T1_MEAL_SEAWEEDSALAD', 'LocationId' => 1002, 'QualityLevel' => 1, 'EnchantmentLevel' => 0, 'UnitPriceSilver' => 2490000, 'Amount' => 15, 'AuctionType' => 'offer', 'Expires' => '2024-04-15T00:24:27.605927' } }
  let(:orders) { [order1, order2] }
  let(:subject) { described_class.new(orders, 'west') }

  before do
    REDIS.flushall
    MarketOrder.delete_all
  end

  describe '#process' do
    let(:subject) { described_class.new(orders, 'west') }

    before do
      allow(subject).to receive(:dedupe_24h)
      allow(subject).to receive(:update_dupe_records)
      allow(subject).to receive(:separate_new_from_old_records)
      allow(subject).to receive(:add_new_records)
      allow(subject).to receive(:update_old_records)
    end

    it 'calls dedupe_24h' do
      expect(subject).to receive(:dedupe_24h)
      subject.process
    end

    it 'calls update_dupe_records' do
      expect(subject).to receive(:update_dupe_records)
      subject.process
    end

    it 'calls separate_new_from_old_records' do
      expect(subject).to receive(:separate_new_from_old_records)
      subject.process
    end

    it 'calls add_new_records' do
      expect(subject).to receive(:add_new_records)
      subject.process
    end

    it 'calls update_old_records' do
      expect(subject).to receive(:update_old_records)
      subject.process
    end
  end

  describe '#dedupe_24h' do
    let(:order1) { { 'order1' => 'Data' } }
    let(:order2) { { 'order2' => 'Data' } }
    let(:orders) { [order1, order2] }

    it 'returns 2 deduped records' do
      subject = described_class.new(orders, 'west')
      expect(subject.dedupe_24h).to eq([[], orders])
    end

    it 'returns 1 deduped record' do
      # store order1 in redis
      described_class.new([order1], 'west').dedupe_24h

      # now dedupe order1 and order2, resulting in order2 being non-dupe
      subject = described_class.new([order1, order2], 'west')
      expect(subject.dedupe_24h).to eq([[order1], [order2]])
    end

    it 'returns 0 deduped records' do
      described_class.new([order1, order2], 'west').dedupe_24h
      subject = described_class.new([order1, order2], 'west')
      subject.dedupe_24h
      expect(subject.dedupe_24h).to eq([[order1, order2], []])
    end

    it 'calls redis.get' do
      subject = described_class.new([order1], 'west')
      expect(REDIS).to receive(:get).with("RECORD_SHA256_24H:#{Digest::SHA256.hexdigest(order1.to_s)}").and_return(nil)
      subject.dedupe_24h
    end

    it 'calls redis.set' do
      subject = described_class.new([order1], 'west')
      allow(REDIS).to receive(:get).and_return(nil)
      expect(REDIS).to receive(:set).with("RECORD_SHA256_24H:#{Digest::SHA256.hexdigest(order1.to_s)}", 1, ex: 86400)
      subject.dedupe_24h
    end
  end

  describe '#update_dupe_records' do
    it 'updates 1 record' do
      subject = described_class.new(orders, 'west')
      subject.add_new_records([order1])
      Timecop.travel(1.minute.from_now)
      expect { subject.update_dupe_records([order1]) }.to change { MarketOrder.find_by(albion_id: order1['Id']).updated_at }
      Timecop.return
    end
  end

  describe '#separate_new_from_old_records' do
    let(:new_order) { { 'Id' => 12226808119, 'ItemTypeId' => 'T1_MEAL_SEAWEEDSALAD', 'ItemGroupTypeId' => 'T1_MEAL_SEAWEEDSALAD', 'LocationId' => 1002, 'QualityLevel' => 1, 'EnchantmentLevel' => 0, 'UnitPriceSilver' => 2490000, 'Amount' => 15, 'AuctionType' => 'offer', 'Expires' => '2024-04-15T00:24:27.605927' } }

    it 'returns 1 new and 1 old record' do
      allow(MarketOrder).to receive(:where).with(albion_id: [order1['Id'], order2['Id']]).and_return(double(pluck: [order1['Id']]))
      expect(subject.separate_new_from_old_records(orders)).to eq([[order2], [order1]])
    end

    it 'returns 2 new records' do
      allow(MarketOrder).to receive(:where).with(albion_id: [order1['Id'], order2['Id']]).and_return(double(pluck: []))
      expect(subject.separate_new_from_old_records(orders)).to eq([orders, []])
    end

    it 'returns 2 old records' do
      allow(MarketOrder).to receive(:where).with(albion_id: [order1['Id'], order2['Id']]).and_return(double(pluck: [order1['Id'], order2['Id']]))
      expect(subject.separate_new_from_old_records(orders)).to eq([[], orders])
    end
  end

  describe '#add_new_records' do
    let(:new_order) { { 'Id' => 12226808119, 'ItemTypeId' => 'T1_MEAL_SEAWEEDSALAD', 'ItemGroupTypeId' => 'T1_MEAL_SEAWEEDSALAD', 'LocationId' => 1002, 'QualityLevel' => 1, 'EnchantmentLevel' => 0, 'UnitPriceSilver' => 2490000, 'Amount' => 15, 'AuctionType' => 'offer', 'Expires' => '2024-04-15T00:24:27.605927' } }

    it 'adds 1 new record' do
      expect { subject.add_new_records([new_order]) }.to change { MarketOrder.count }.by(1)
    end

    it 'adds 2 new records' do
      expect { subject.add_new_records(orders) }.to change { MarketOrder.count }.by(2)
    end

    it 'calls MarketOrder.insert_all' do
      expect(MarketOrder).to receive(:insert_all)
      subject.add_new_records([new_order])
    end
  end

  describe '#update_old_records' do
    it 'updates 1 old record' do
      subject.add_new_records([order1])
      order1['UnitPriceSilver'] = 1000000
      subject.update_old_records([order1])
      expect(MarketOrder.find_by(albion_id: order1['Id']).price).to eq(1000000)
    end

    it 'updates 2 old records' do
      subject.add_new_records(orders)
      orders.each { |order| order['UnitPriceSilver'] = 1000000 }
      subject.update_old_records(orders)
      orders.each { |order| expect(MarketOrder.find_by(albion_id: order['Id']).price).to eq(1000000) }
    end
  end
end
