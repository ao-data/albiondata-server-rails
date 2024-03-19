# == Schema Information
#
# Table name: gold_prices
#
#  id        :bigint           unsigned, not null, primary key
#  price     :integer          unsigned
#  timestamp :datetime
#
# Indexes
#
#  idx_gold_prices_timestamp  (timestamp)
#
class GoldPrice < ApplicationRecord
  
end
