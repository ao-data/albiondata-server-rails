namespace :aodp do
  namespace :ipdb do
    desc "One-off: copy the legacy bad_ips set into the bad_ips_by_time sorted set"
    task migrate_bad_ips: :environment do
      count = Ipdb.migrate_legacy_bad_ips
      puts "Migrated #{count} bad IPs from #{Ipdb::LEGACY_BAD_IPS_KEY} to #{Ipdb::BAD_IPS_KEY}."
      puts "#{Ipdb::LEGACY_BAD_IPS_KEY} was left in place; DEL it once you've checked #{Ipdb::BAD_IPS_KEY}."
    end
  end
end
