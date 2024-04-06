FactoryBot.define do
  factory :gold_price do
    price { 10000 }
    timestamp { DateTime.now }
  end

end
