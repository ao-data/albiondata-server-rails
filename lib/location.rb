module Location

  # Run bin/rails aodp:parse_smuggers_den_ids to get the latest list of locations for the Smuggler's Dens
  CITY_TO_LOCATION = {
    "swampcross": 4,
    "thetford": 7,
    "thetfordportal": 301,
    "morganasrest": 8,
    "lymhurst": 1002,
    "lymhurstportal": 1301,
    "forestcross": 1006,
    "merlynsrest": 1012,
    "steppecross": 2002,
    "bridgewatch": 2004,
    "bridgewatchportal": 2301,
    "highlandcross": 3002,
    "BlackMarket": 3003,
    "Blackmarket": 3003,
    "blackmarket": 3003,
    "Black Market": 3003,
    "caerleon2": 3005,
    "caerleon": 3005,
    "martlock": 3008,
    "martlockportal": 3301,
    "fortsterling": 4002,
    "fortsterlingportal": 4301,
    "mountaincross": 4006,
    "arthursrest": 4300,
    "brecilien": 5003,
    "meltwaterbogsmugglersden": 307,
    "willowshadeicemarshsmugglersden": 320,
    "springsumpbasinsmugglersden": 321,
    "runnelveinsinksmugglersden": 341,
    "willowshadehillssmugglersden": 344,
    "sunkenboughwoodssmugglersden": 349,
    "scuttlesinkmarshsmugglersden": 353,
    "deadpineforestsmugglersden": 1312,
    "westwealdthicketsmugglersden": 1323,
    "timberslopegrovesmugglersden": 1339,
    "timberscarcopsesmugglersden": 1342,
    "deepwoodcopsesmugglersden": 1343,
    "driftwoodhollowsmugglersden": 1348,
    "rivercopsefountsmugglersden": 1359,
    "drybasinriverbedsmugglersden": 2308,
    "sunfangravinesmugglersden": 2310,
    "thirstwatersteppesmugglersden": 2311,
    "bleachskulldesertsmugglersden": 2333,
    "farshoreheathsmugglersden": 2336,
    "slakesandsmesasmugglersden": 2342,
    "sunfangwastelandsmugglersden": 2344,
    "dryveinconfluencesmugglersden": 2347,
    "sunstrandquicksandssmugglersden": 2348,
    "murdergulchcrosssmugglersden": 3306,
    "razorrockvergesmugglersden": 3344,
    "razorrockbanksmugglersden": 3345,
    "gravemoundknollsmugglersden": 3351,
    "murdergulchravinesmugglersden": 3355,
    "highstonelochsmugglersden": 3357,
    "floatshoalfloesmugglersden": 4313,
    "iceburnfirthsmugglersden": 4318,
    "everwinterpeaksmugglersden": 4322,
    "muntenfellsmugglersden": 4345,
    "frostspringvolcanosmugglersden": 4351,
    "whitepeaktundrasmugglersden": 4357,
  }

  LOCATION_TO_CITY = CITY_TO_LOCATION.invert.transform_keys(&:to_s)

  PORTAL_TO_CITY = {
    301 => 7,     # ThetfordPortal to Thetford
    1301 => 1002, # LymhurstPortal to Lymhurst
    2301 => 2004, # BridgewatchPortal to Bridgewatch
    3301 => 3008, # MartlockPortal to Martlock
    4301 => 4002, # FortSterlingPortal to FortSterling
    3013 => 3005  # Caerleon2 to Caerleon
  }

  SPLIT_WORDS = ['swamp', 'portal', 'cross', 'market', 'sterling', 'rest', 'smugglers', 'den',
                 'bank', 'basin', 'bog', 'confluence', 'copse', 'cross', 'desert', 'fell', 'firth', 'floe', 'forest',
                 'fount', 'grove', 'heath', 'hills', 'hollow', 'icemarsh', 'knoll', 'loch', 'marsh', 'mesa', 'peak',
                 'quicksands', 'ravine', 'riverbed', 'sink', 'steppe', 'thicket', 'tundra', 'verge', 'volcano',
                 'wasteland', 'woods']

  SMUGGLERS_DEN_LOCATIONS = [307, 320, 321, 341, 344, 349, 353, 1312, 1323, 1339, 1342, 1343, 1348, 1359, 2308, 2310,
                            2311, 2333, 2336, 2342, 2344, 2347, 2348, 3306, 3344, 3345, 3351, 3355, 3357, 4313, 4318,
                            4322, 4345, 4351, 4357]

  def location_to_city(location)
    LOCATION_TO_CITY[location.to_s] || location.to_s.to_sym
  end

  def city_to_location(city)
    CITY_TO_LOCATION[city.to_sym] || city.to_i
  end

  def get_locations(params)
    default_locations = [3005, 7, 4002, 1002, 2004, 3008, 3003, 5003]
    locations = params[:locations]

    # locations = nil if params[:query_string].include?('locations[]')
    locations = locations&.map { |l| city_to_location(l.gsub(' ', '').downcase) }if locations.is_a?(Array)

    locations = default_locations if locations.nil?
    locations = default_locations if locations == 0 || locations == '0'
    locations = locations&.split(',')&.map { |l| city_to_location(l.gsub(' ', '').gsub("'", '').downcase) } if locations.is_a?(String)

    # check if locations array includes any SMUGGLERS_DEN_LOCATIONS, if so, replace only those locations
    # with the entire SMUGGLERS_DEN_LOCATIONS array
    unless (locations & SMUGGLERS_DEN_LOCATIONS).empty?
      locations = locations - (locations & SMUGGLERS_DEN_LOCATIONS) + SMUGGLERS_DEN_LOCATIONS
    end
    
    locations
  end

  def humanize_city(city)
    SPLIT_WORDS.each { |w| city = city.to_s.gsub(w, "_#{w}").titleize}
    city = city.gsub('Fo Rest', 'Forest').gsub('fo Rest', 'Forest')
    city
  end

end
