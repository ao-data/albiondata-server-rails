namespace :aodp do
  desc "Parse Smuggler's Den IDs"
  task parse_smuggers_den_ids: :environment do

    branch = "update/20250130-staging"
    url = "https://raw.githubusercontent.com/ao-data/ao-bin-dumps/refs/heads/#{branch}/formatted/world.txt"
    data = HTTParty.get(url).body.split("\n")

    ids = []
    data.each do |line|
      parts = line.split(':').map(&:strip)
      next unless parts[0].include?("BLACKBANK-")
      id = parts[0].gsub("BLACKBANK-", "")
      ids << id
    end

    # output int list of smugglers den locations
    puts "\n\n\n\n\n"
    puts "IDs for SMUGGERS_DEN_LOCATIONS in locations.rb:\n#{ids.sort.map(&:to_i).join(", ")}"

    # output list of items to add to CITY_TO_LOCATION
    puts "\n\nAdditional cities for CITY_TO_LOCATION in locations.rb: "

    second_words = []
    ids.sort.each do |id|
      data.each do |line|
        # does this line match the location id?
        if line.start_with?("#{id}:")
          # split the line
          parts = line.split(':').map(&:strip)

          # get all words after the first word of the city name (ex: Den in "Smugglers Den")
          city_words = parts[1].split(" ")[1].split(" ")

          # compile list of words
          city_words.each do |word|
            second_words << word unless second_words.include?(word)
          end

          # output this smuggler den's 'city to location' data
          puts "\"#{parts[1].gsub("'", "").gsub(" ", "").downcase}smugglersden\": #{id.to_i},"

          break
        end
      end
    end

    puts "\n\nAdditional SPLIT_WORDS for locations.rb:\n'#{second_words.sort.uniq.map(&:downcase).join("', '")}'"

    puts "\n\n\n\n\n"
  end
end