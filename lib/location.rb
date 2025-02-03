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
    "brecilien": 5003,
    "smugglersnetwork": 307,
    "morganasrestsmugglersnetwork": 8,
    "meltwaterbogsmugglersnetwork": 307,
    "willowshadeicemarshsmugglersnetwork": 320,
    "springsumpbasinsmugglersnetwork": 321,
    "runnelveinsinksmugglersnetwork": 341,
    "willowshadehillssmugglersnetwork": 344,
    "sunkenboughwoodssmugglersnetwork": 349,
    "scuttlesinkmarshsmugglersnetwork": 353,
    "merlynsrestsmugglersnetwork": 1012,
    "deadpineforestsmugglersnetwork": 1312,
    "westwealdthicketsmugglersnetwork": 1323,
    "timberslopegrovesmugglersnetwork": 1339,
    "timberscarcopsesmugglersnetwork": 1342,
    "deepwoodcopsesmugglersnetwork": 1343,
    "driftwoodhollowsmugglersnetwork": 1348,
    "rivercopsefountsmugglersnetwork": 1359,
    "drybasinriverbedsmugglersnetwork": 2308,
    "sunfangravinesmugglersnetwork": 2310,
    "thirstwatersteppesmugglersnetwork": 2311,
    "bleachskulldesertsmugglersnetwork": 2333,
    "farshoreheathsmugglersnetwork": 2336,
    "slakesandsmesasmugglersnetwork": 2342,
    "sunfangwastelandsmugglersnetwork": 2344,
    "dryveinconfluencesmugglersnetwork": 2347,
    "sunstrandquicksandssmugglersnetwork": 2348,
    "murdergulchcrosssmugglersnetwork": 3306,
    "razorrockvergesmugglersnetwork": 3344,
    "razorrockbanksmugglersnetwork": 3345,
    "gravemoundknollsmugglersnetwork": 3351,
    "murdergulchravinesmugglersnetwork": 3355,
    "highstonelochsmugglersnetwork": 3357,
    "arthursrestsmugglersnetwork": 4300,
    "floatshoalfloesmugglersnetwork": 4313,
    "iceburnfirthsmugglersnetwork": 4318,
    "everwinterpeaksmugglersnetwork": 4322,
    "muntenfellsmugglersnetwork": 4345,
    "frostspringvolcanosmugglersnetwork": 4351,
    "whitepeaktundrasmugglersnetwork": 4357,
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

  SPLIT_WORDS = ['swamp', 'portal', 'cross', 'market', 'sterling', 'rest', 'smugglers', 'network',
                 'bank', 'basin', 'bog', 'confluence', 'copse', 'cross', 'desert', 'fell', 'firth', 'floe', 'forest',
                 'fount', 'grove', 'heath', 'hills', 'hollow', 'icemarsh', 'knoll', 'loch', 'marsh', 'mesa', 'peak',
                 'quicksands', 'ravine', 'riverbed', 'sink', 'steppe', 'thicket', 'tundra', 'verge', 'volcano',
                 'wasteland', 'woods']

  SMUGGLERS_NETWORK_LOCATIONS = [8, 307, 320, 321, 341, 344, 349, 353, 1012, 1312, 1323, 1339, 1342, 1343, 1348, 1359,
                             2308, 2310, 2311, 2333, 2336, 2342, 2344, 2347, 2348, 3306, 3344, 3345, 3351, 3355,
                             3357, 4300, 4313, 4318, 4322, 4345, 4351, 4357]

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
    unless (locations & SMUGGLERS_NETWORK_LOCATIONS).empty?
      locations = locations - (locations & SMUGGLERS_NETWORK_LOCATIONS) + SMUGGLERS_NETWORK_LOCATIONS
    end
    
    locations
  end

  def humanize_city(city)
    SPLIT_WORDS.each { |w| city = city.to_s.gsub(w, "_#{w}").titleize}
    city = city.gsub('Fo Rest', 'Forest').gsub('fo Rest', 'Forest')
    city
  end

end
