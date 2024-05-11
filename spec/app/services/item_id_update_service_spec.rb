describe ItemIdUpdateService, type: :service do
  let(:item1) { { 'Index' => "1", 'UniqueName' => 'T1_MEAL_SEAWEEDSALAD' } }
  let(:item2) { { 'Index' => "2", 'UniqueName' => 'T1_MEAL_SEAWEEDSALAD' } }
  let(:items) { [item1, item2] }

  let(:subject) { described_class.new('west') }

  before do
    REDIS['west'].flushall
  end

  describe '.update' do
    before do
      allow(subject).to receive(:get_items_from_github).and_return(items)
    end

    it 'adds 2 items to the ITEM_IDS hash' do
      expect(REDIS['west']).to receive(:hset).with('ITEM_IDS', item1['Index'], item1['UniqueName'])
      expect(REDIS['west']).to receive(:hset).with('ITEM_IDS', item2['Index'], item2['UniqueName'])
      subject.update
    end

    it 'calls REDIS.del' do
      expect(REDIS['west']).to receive(:del).with('ITEM_IDS')
      subject.update
    end
  end

  describe '.get_items_from_github' do
    it 'returns items from github' do
      expect(HTTParty).to receive(:get).with("https://raw.githubusercontent.com/ao-data/ao-bin-dumps/master/formatted/items.json").and_return(double(body: items.to_json))
      expect(subject.get_items_from_github).to eq(items)
    end
  end
end
