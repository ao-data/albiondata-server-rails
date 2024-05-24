RSpec.describe Quality, :type => :module do

  include Quality

  describe '#get_qualities' do
    it 'returns default list of qualities if qualities is nil' do
      params = { qualities: nil}
      expect(get_qualities(params)).to eq([1])
    end

    it 'returns default list of qualities if qualities is 0' do
      params = { qualities: 0}
      expect(get_qualities(params)).to eq([1,2,3,4,5])
    end

    it 'returns empty list of qualities if qualities is an empty string' do
      params = { qualities: ''}
      expect(get_qualities(params)).to eq([])
    end

    it 'returns empty list of qualities if qualities is an empty array' do
      params = { qualities: []}
      expect(get_qualities(params)).to eq([])
    end

    it 'returns string converted qualities if qualities is a string' do
      params = { qualities: '1,2'}
      expect(get_qualities(params)).to eq([1,2])
    end

    it 'returns string converted qualities if qualities is an array' do
      params = { qualities: ['1', '2']}
      expect(get_qualities(params)).to eq([1,2])
    end
  end

end
