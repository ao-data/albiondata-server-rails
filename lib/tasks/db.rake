
namespace :aodp do
  namespace :db do
    desc "migrate"
    task migrate: :environment do
      [:east, :west, :europe].each do |server|
        Multidb.use(server) do
          puts "Setting up the database for #{server}..."
          Rake::Task["db:migrate"].invoke
        end
      end
    end

  end
end
