source "https://rubygems.org"

ruby "3.3.1"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.3", ">= 7.1.3.2"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use sqlite3 as the database for Active Record
gem "sqlite3", "~> 1.4"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Redis adapter to run Action Cable in production
gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# gem 'mysql2', '~> 0.5.6'
gem 'annotate', '~> 3.2'
gem 'trilogy', '~> 2.7'
gem 'route_downcaser', '~> 2.0'
gem 'sidekiq', '~> 7.2', '>= 7.2.2'
gem 'sidekiq-cron', '~> 1.12'
gem 'nats-pure', '~> 2.2', '>= 2.2.1'
gem 'httparty', '~> 0.21.0'
gem 'abuseipdb-rb', '~> 0.0.2'
gem 'rack-cors', '~> 2.0', '>= 2.0.2'
gem 'rack-attack', '~> 6.7'
# gem 'ar-multidb', '~> 0.7.0'
gem 'ar-multidb', git: 'https://github.com/phendryx/multidb.git', branch: 'fix/bold-fix'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]

  gem 'ffaker', '~> 2.21'
  gem 'rspec-rails', '~> 6.1', '>= 6.1.1'
  gem 'factory_bot_rails', '~> 6.4', '>= 6.4.3'

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  gem "spring"

  gem 'spring-commands-rspec', '~> 1.0', '>= 1.0.4'
  gem 'timecop', '~> 0.9.8'
  gem 'simplecov-rcov', '~> 0.3.7'

  gem 'rack-test', '~> 2.1'
  gem 'database_cleaner', '~> 2.0', '>= 2.0.2'
end

gem 'meta_request', github: 'Nowaker/rails_panel', branch: 'add-support-to-rails-7.1'

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
