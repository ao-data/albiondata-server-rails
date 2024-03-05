# == Schema Information
#
# Table name: market_orders
#
#  albion_id         :bigint           unsigned, not null
#  item_id           :string(255)
#  quality_level     :integer          unsigned
#  enchantment_level :integer          unsigned
#  price             :bigint           unsigned
#  initial_amount    :integer          unsigned
#  amount            :integer          unsigned
#  auction_type      :string(255)
#  expires           :datetime
#  location          :integer          unsigned, not null
#  id                :bigint           unsigned, not null, primary key
#  created_at        :datetime
#  updated_at        :datetime
#  deleted_at        :datetime
#
class MarketOrder < ApplicationRecord
  
end
