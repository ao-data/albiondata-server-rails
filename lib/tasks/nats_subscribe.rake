
namespace :custom_task do
  desc "Subscribe to NATS"
  task nats_subscribe: :environment do
    NatsService.new.listen
  end
end
