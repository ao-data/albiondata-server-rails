# -*- encoding: utf-8 -*-
# stub: meta_request 0.7.3 ruby lib

Gem::Specification.new do |s|
  s.name = "meta_request".freeze
  s.version = "0.7.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Dejan Simic".freeze]
  s.date = "2024-05-04"
  s.description = "Supporting gem for Rails Panel (Google Chrome extension for Rails development)".freeze
  s.email = "desimic@gmail.com".freeze
  s.files = ["README.md".freeze, "lib/meta_request.rb".freeze, "lib/meta_request/app_notifications.rb".freeze, "lib/meta_request/app_request.rb".freeze, "lib/meta_request/config.rb".freeze, "lib/meta_request/event.rb".freeze, "lib/meta_request/log_interceptor.rb".freeze, "lib/meta_request/middlewares.rb".freeze, "lib/meta_request/middlewares/app_request_handler.rb".freeze, "lib/meta_request/middlewares/headers.rb".freeze, "lib/meta_request/middlewares/meta_request_handler.rb".freeze, "lib/meta_request/railtie.rb".freeze, "lib/meta_request/storage.rb".freeze, "lib/meta_request/utils.rb".freeze, "lib/meta_request/version.rb".freeze]
  s.homepage = "https://github.com/dejan/rails_panel/tree/master/meta_request".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.10".freeze
  s.summary = "Request your Rails request".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<rack-contrib>.freeze, [">= 1.1", "< 3"])
  s.add_runtime_dependency(%q<railties>.freeze, [">= 3.0.0", "< 7.2"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.8.0"])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 0.74.0"])
end
