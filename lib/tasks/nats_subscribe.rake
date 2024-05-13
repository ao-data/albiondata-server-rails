namespace :aodp do
  namespace :nats do
    desc "Subscribe to NATS West server"
    task subscribe_west: :environment do
      NatsService.new('west').listen
    end

    desc "Subscribe to NATS East server"
    task subscribe_east: :environment do
      NatsService.new('east').listen
    end

    desc "Subscribe to NATS Europe server"
    task subscribe_europe: :environment do
      NatsService.new('europe').listen
    end
  end
end
