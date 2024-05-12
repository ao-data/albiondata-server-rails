


namespace :custom_task do
  desc "Pull items.json and update item_ids in redis"
  task item_id_update: :environment do
    ItemIdUpdateService.new('west').update
    ItemIdUpdateService.new('east').update
    ItemIdUpdateService.new('europe').update
  end
end
