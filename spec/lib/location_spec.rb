RSpec.describe Location, :type => :module do

  include Location

  describe '#location_to_city' do
    it 'it returns a city name for a location' do
      expect(location_to_city(3005)).to eq(:caerleon)
    end

    it 'it returns a city name for a location as a string' do
      expect(location_to_city('3005')).to eq(:caerleon)
    end

    it 'it returns a location if there is no city name' do
      expect(location_to_city(1234)).to eq(:'1234')
    end
  end

  describe '#city_to_location' do
    it 'it returns a location for a city' do
      expect(city_to_location(:caerleon)).to eq(3005)
    end

    it 'it returns a location for a city as a string' do
      expect(city_to_location('caerleon')).to eq(3005)
    end

    it 'it returns a city if there is no location' do
      expect(city_to_location('1234')).to eq(1234)
    end
  end

  describe '#get_locations' do
    it 'it returns default list of locations if locations is nil' do
      params = { locations: nil}
      expect(get_locations(params)).to eq([3005, 7, 4002, 1002, 2004, 3008, 3003, 5003])
    end

    it 'it returns default list of locations if locations is 0' do
      params = { locations: 0}
      expect(get_locations(params)).to eq([3005, 7, 4002, 1002, 2004, 3008, 3003, 5003])
    end

    it 'it returns empty list of locations if locations is an empty string' do
      params = { locations: ''}
      expect(get_locations(params)).to eq([])
    end

    it 'it returns empty list of locations if locations is an empty array' do
      params = { locations: []}
      expect(get_locations(params)).to eq([])
    end

    it 'it returns string converted locations if locations is a string' do
      params = { locations: 'martlock,caerleon2'}
      expect(get_locations(params)).to eq([3008, 3005])
    end

    it 'it returns string converted locations all smugglers dens' do
      params = { locations: 'Deadpine Forest Smugglers Network'}
      expect(get_locations(params)).to eq(Location::SMUGGLERS_NETWORK_LOCATIONS)
    end

    it 'it returns all smugglers dens when there is a \' in "smugglers"' do
      params = { locations: "Deadpine Forest Smuggler's Network"}
      expect(get_locations(params)).to eq(Location::SMUGGLERS_NETWORK_LOCATIONS)
    end

    it 'it returns string converted locations if locations is an array' do
      params = { locations: ['martlock', 'caerleon2']}
      expect(get_locations(params)).to eq([3008, 3005])
    end

    it 'it returns string converted locations if locations is an array with spaces' do
      params = { locations: ['fortsterling', 'caerleon 2']}
      expect(get_locations(params)).to eq([4002, 3005])
    end
  end

  describe '#humanize_city' do
    it 'it returns a humanized city name "martlock"' do
      expect(humanize_city('martlock')).to eq('Martlock')
    end

    it 'it returns a humanized city name for "murdergulchravinesmugglersnetwork"' do
      expect(humanize_city('murdergulchravinesmugglersnetwork')).to eq('Murdergulch Ravine Smugglers Network')
    end

    it 'it returns a humanized city name with multiple words' do
      expect(humanize_city('mountaincross')).to eq('Mountain Cross')
    end

    it 'it handles forestcross properly' do
      expect(humanize_city('forestcross')).to eq('Forest Cross')
    end
  end

  describe '#parse_location_integer' do
    it 'it returns portal city for numeric portal locations' do
      expect(parse_location_integer(3013)).to eq(3005)
    end
  
    it 'it returns location for valid numeric locations' do
      expect(parse_location_integer(3005)).to eq(3005)
    end
  
    it 'it returns nil for invalid numeric locations' do
      expect(parse_location_integer(9999)).to be_nil
    end
  
    it 'it handles Auction2 locations' do
      expect(parse_location_integer('3013-Auction2')).to eq(3005)
    end
  
    it 'it handles HellDen locations' do
      expect(parse_location_integer('0000-HellDen')).to eq(7)
    end
  
    it 'it handles locations with @ prefix' do
      expect(parse_location_integer('LOTSOFSTUFF@3005')).to eq(3005)
    end
  
    it 'it handles BLACKBANK locations' do
      expect(parse_location_integer('BLACKBANK-2311')).to eq(2311)
    end
  
    it 'it handles BLACKBANK locations with @ prefix' do
      expect(parse_location_integer('LOTSOFSTUFF@BLACKBANK-2311')).to eq(2311)
    end
  
    it 'it returns nil for non-numeric strings' do
      expect(parse_location_integer('pizza')).to be_nil
    end
  
    it 'it returns nil for nil input' do
      expect(parse_location_integer(nil)).to be_nil
    end
end

end
