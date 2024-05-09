# -*- encoding: utf-8 -*-
# stub: ar-multidb 0.7.0 ruby lib

Gem::Specification.new do |s|
  s.name = "ar-multidb".freeze
  s.version = "0.7.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/OutOfOrder/multidb/blob/master/CHANGELOG.md", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/OutOfOrder/multidb" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Alexander Staubo".freeze, "Edward Rudd".freeze]
  s.date = "2024-05-09"
  s.description = "Multidb is an ActiveRecord extension for switching between multiple database connections, such as primary/replica setups.".freeze
  s.email = ["alex@bengler.no".freeze, "urkle@outoforder.cc".freeze]
  s.files = [".github/workflows/prs.yml".freeze, ".gitignore".freeze, ".rubocop.yml".freeze, ".simplecov".freeze, "CHANGELOG.md".freeze, "Gemfile".freeze, "LICENSE".freeze, "README.markdown".freeze, "Rakefile".freeze, "ar-multidb.gemspec".freeze, "gemfiles/activerecord-5.1.gemfile".freeze, "gemfiles/activerecord-5.2.gemfile".freeze, "gemfiles/activerecord-6.0.gemfile".freeze, "gemfiles/activerecord-6.1.gemfile".freeze, "gemfiles/activerecord-7.0.gemfile".freeze, "gemfiles/activerecord-7.1.gemfile".freeze, "lib/ar-multidb.rb".freeze, "lib/multidb.rb".freeze, "lib/multidb/balancer.rb".freeze, "lib/multidb/candidate.rb".freeze, "lib/multidb/configuration.rb".freeze, "lib/multidb/log_subscriber.rb".freeze, "lib/multidb/model_extensions.rb".freeze, "lib/multidb/version.rb".freeze, "spec/lib/multidb/balancer_spec.rb".freeze, "spec/lib/multidb/candidate_spec.rb".freeze, "spec/lib/multidb/configuration_spec.rb".freeze, "spec/lib/multidb/log_subscriber_extension_spec.rb".freeze, "spec/lib/multidb/model_extensions_spec.rb".freeze, "spec/lib/multidb_spec.rb".freeze, "spec/spec_helper.rb".freeze, "spec/support/have_database_matcher.rb".freeze, "spec/support/helpers.rb".freeze]
  s.homepage = "https://github.com/OutOfOrder/multidb".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.rubygems_version = "3.5.9".freeze
  s.summary = "Multidb is an ActiveRecord extension for switching between multiple database connections, such as primary/replica setups.".freeze
  s.test_files = ["spec/lib/multidb/balancer_spec.rb".freeze, "spec/lib/multidb/candidate_spec.rb".freeze, "spec/lib/multidb/configuration_spec.rb".freeze, "spec/lib/multidb/log_subscriber_extension_spec.rb".freeze, "spec/lib/multidb/model_extensions_spec.rb".freeze, "spec/lib/multidb_spec.rb".freeze, "spec/spec_helper.rb".freeze, "spec/support/have_database_matcher.rb".freeze, "spec/support/helpers.rb".freeze]

  s.installed_by_version = "3.5.9".freeze if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<activerecord>.freeze, [">= 5.1".freeze, "< 7.2".freeze])
  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 5.1".freeze, "< 7.2".freeze])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.8".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.28.0".freeze])
  s.add_development_dependency(%q<rubocop-rspec>.freeze, ["~> 2.10.0".freeze])
  s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.21.2".freeze])
  s.add_development_dependency(%q<simplecov-lcov>.freeze, ["~> 0.8.0".freeze])
  s.add_development_dependency(%q<sqlite3>.freeze, ["~> 1.3".freeze])
end
