


namespace :custom_task do
  desc "Pull items.json and update item_ids in redis"
  task item_id_update: :environment do
    ItemIdUpdateService.update
  end
end
