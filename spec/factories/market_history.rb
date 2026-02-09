# == Schema Information
#
# Table name: market_history
#
#  id            :bigint           unsigned, not null, primary key
#  aggregation   :integer          default(6), not null
#  item_amount   :bigint           unsigned, not null
#  location      :integer          unsigned, not null
#  quality       :integer          unsigned, not null
#  silver_amount :bigint           unsigned, not null
#  timestamp     :datetime         not null
#  item_id       :string(128)      not null
#
# Indexes
#
#  Aggregation  (aggregation,timestamp)
#  Main         (item_id,quality,location,timestamp,aggregation) UNIQUE
#  Simple       (item_id,timestamp,aggregation)
#
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
