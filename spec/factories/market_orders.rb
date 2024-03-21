# == Schema Information
#
# Table name: market_orders
#
#  id                :bigint           unsigned, not null, primary key
#  amount            :integer          unsigned
#  auction_type      :string(255)
#  deleted_at        :datetime
#  enchantment_level :integer          unsigned
#  expires           :datetime
#  initial_amount    :integer          unsigned
#  location          :integer          unsigned, not null
#  price             :bigint           unsigned
#  quality_level     :integer          unsigned
#  created_at        :datetime
#  updated_at        :datetime
#  albion_id         :bigint           unsigned, not null
#  item_id           :string(255)
#
# Indexes
#
#  expired                      (deleted_at,expires,updated_at)
#  main                         (item_id,location,updated_at,deleted_at)
#  uix_market_orders_albion_id  (albion_id) UNIQUE
#
FactoryBot.define do
  factory :market_order do
    albion_id { FFaker::Number.number(digits: 16) }
    location { 3005 }
    price { FFaker::Number.number(digits: 4) }
    initial_amount { FFaker::Number.number(digits: 2) }
    amount { initial_amount }
    quality_level { FFaker::Number.between(from: 1, to: 5) }
    enchantment_level { FFaker::Number.between(from: 1, to: 5) }
    expires { FFaker::Date.between(DateTime.now, DateTime.now + 1.months) }
    created_at { DateTime.now }
    updated_at { created_at }

    trait :t4_bag do
      item_id { 'T4_BAG' }
    end

    trait :t5_bag do
      item_id { 'T5_BAG' }
    end

    trait :in3005 do
      location { 3005 }
    end

    trait :quality1 do
      quality_level { 1 }
    end

    trait :price_low do
      price { 10 }
    end

    trait :price_high do
      price { 99 }
    end

    trait :offer do
      auction_type { 'offer' }
    end

    trait :request do
      auction_type { 'request' }
    end

    trait :new do
      created_at { DateTime.parse('2024-03-09 9:04:00') }
      updated_at { created_at }
    end

    trait :old do
      created_at { DateTime.parse('2024-03-09 8:32:00') }
      updated_at { created_at }
    end

    trait :oldest do
      created_at { DateTime.parse('2024-03-09 8:11:00') }
      updated_at { created_at }
    end

    factory :market_order_new_offer_low,    traits: [:in3005, :t4_bag, :offer, :quality1, :price_low, :new]
    factory :market_order_new_offer_high,    traits: [:in3005, :t4_bag, :offer, :quality1, :price_high, :new]
    factory :market_order_old_offer_low,    traits: [:in3005, :t4_bag, :offer, :quality1, :price_low, :old]
    factory :market_order_old_offer_high,    traits: [:in3005, :t4_bag, :offer, :quality1, :price_high, :old]
    factory :market_order_oldest_offer_low,    traits: [:in3005, :t4_bag, :offer, :quality1, :price_low, :oldest]
    factory :market_order_oldest_offer_high,    traits: [:in3005, :t4_bag, :offer, :quality1, :price_high, :oldest]

    factory :market_order_new_request_low,    traits: [:in3005, :t4_bag, :request, :quality1, :price_low, :new]
    factory :market_order_new_request_high,    traits: [:in3005, :t4_bag, :request, :quality1, :price_high, :new]
    factory :market_order_old_request_low,    traits: [:in3005, :t4_bag, :request, :quality1, :price_low, :old]
    factory :market_order_old_request_high,    traits: [:in3005, :t4_bag, :request, :quality1, :price_high, :old]
    factory :market_order_oldest_request_low,    traits: [:in3005, :t4_bag, :request, :quality1, :price_low, :oldest]
    factory :market_order_oldest_request_high,    traits: [:in3005, :t4_bag, :request, :quality1, :price_high, :oldest]

  end
end 
