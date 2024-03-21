class ItemIdUpdateService
  def self.update
    url = "https://raw.githubusercontent.com/ao-data/ao-bin-dumps/master/formatted/items.json"
    response = HTTParty.get(url)
    items = JSON.parse(response.body)

    REDIS.del('ITEM_IDS')
    counter = 0
    items.each do |item|
      counter += 1
      puts "Adding #{item['Index']} - #{item['UniqueName']} to the ITEM_IDS hash."
      REDIS.hset('ITEM_IDS', item['Index'], item['UniqueName'])
    end
    puts "Added #{counter} items to the ITEM_IDS hash."
  end
end