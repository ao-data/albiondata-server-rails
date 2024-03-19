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
class MarketOrder < ApplicationRecord
  include ActiveModel::Dirty
end
