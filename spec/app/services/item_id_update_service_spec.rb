describe ItemIdUpdateService, type: :service do
  let(:item1) { { 'Index' => "1", 'UniqueName' => 'T1_MEAL_SEAWEEDSALAD' } }
  let(:item2) { { 'Index' => "2", 'UniqueName' => 'T1_MEAL_SEAWEEDSALAD' } }
  let(:items) { [item1, item2] }

  before do
    REDIS.flushall
  end

  describe '.update' do
    before do
      allow(described_class).to receive(:get_items_from_github).and_return(items)
    end

    it 'adds 2 items to the ITEM_IDS hash' do
      expect(REDIS).to receive(:hset).with('ITEM_IDS', item1['Index'], item1['UniqueName'])
      expect(REDIS).to receive(:hset).with('ITEM_IDS', item2['Index'], item2['UniqueName'])
      described_class.update
    end

    it 'calls REDIS.del' do
      expect(REDIS).to receive(:del).with('ITEM_IDS')
      described_class.update
    end
  end

  describe '.get_items_from_github' do
    it 'returns items from github' do
      expect(HTTParty).to receive(:get).with("https://raw.githubusercontent.com/ao-data/ao-bin-dumps/master/formatted/items.json").and_return(double(body: items.to_json))
      expect(described_class.get_items_from_github).to eq(items)
    end
  end
end
