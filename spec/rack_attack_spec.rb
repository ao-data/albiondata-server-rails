# require "rails_helper"
#
# describe Rack::Attack, type: :request do
#   before(:each) do
#     ENV['THROTTLE_POW_1MIN'] = '10'
#     ENV['THROTTLE_POW_1HOUR'] = '20'
#     ENV['THROTTLE_POW_1DAY'] = '30'
#
#     setup_rack_attack_cache_store
#     avoid_test_overlaps_in_cache
#   end
#
#   def setup_rack_attack_cache_store
#     Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
#   end
#
#   def avoid_test_overlaps_in_cache
#     Rails.cache.clear
#   end
#
#   it "throttle pow minute" do
#
#
#     500.times do
#       get "/pow", headers: { REMOTE_ADDR: '1.2.3.4', HOST: 'west.bleh.com' }
#       # get "/api/v2/", headers: { REMOTE_ADDR: '1.2.3.4' }
#     end
#
#
#     Rack::Attack.throttles.each do |k, throttle|
#       pp k, throttle, '----------'
#       Rack::Attack.cache
#     end
#
#     expect(response).to have_http_status(:too_many_requests)
#   end
# end

# TODO: figure out tests for this..