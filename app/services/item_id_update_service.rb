class ItemIdUpdateService

  def initialize(server_id)
    @server_id = server_id
  end

  def update
    items = get_items_from_github

    REDIS[@server_id].del('ITEM_IDS')
    counter = 0
    items.each do |item|
      counter += 1
      puts "Adding #{item['Index']} - #{item['UniqueName']} to the ITEM_IDS hash."
      REDIS[@server_id].hset('ITEM_IDS', item['Index'], item['UniqueName'])
    end
    puts "Added #{counter} items to the ITEM_IDS hash."
  end

  def get_items_from_github
    url = "https://raw.githubusercontent.com/ao-data/ao-bin-dumps/master/formatted/items.json"
    response = HTTParty.get(url)
    JSON.parse(response.body)
  end
end