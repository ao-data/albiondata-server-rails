# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
ActiveSupport::Inflector.inflections(:en) do |inflect|
  # app/api/stats_api.rb (the StatsAPI Grape class, mounted in config/routes.rb) depends on this
  # acronym resolving "API" correctly at boot — do not remove even though the legacy
  # API::V2::*Controller tree this was originally added for is gone.
  inflect.acronym "API"
end
