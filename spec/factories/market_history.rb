FactoryBot.define do

  factory :market_history do
    item_id { 'T4_BAG' }
    location { '3005' }
    quality { '1' }
    item_amount { 10 }
    silver_amount { 100 }
    timestamp { DateTime.now }
  end

end
