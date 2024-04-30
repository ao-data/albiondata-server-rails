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
class MarketHistory < ApplicationRecord
  include ActiveModel::Dirty
  self.table_name = 'market_history'

  def self.purge_old_data
    continue = true
    start_time = DateTime.now
    limit = 1000
    row_count = 0

    while continue && start_time > 1.minutes.ago
      deleted_rows = MarketHistory.where(aggregation: 1).and(MarketHistory.where('timestamp < ?', 7.days.ago)).limit(limit).delete_all
      row_count += deleted_rows
      continue = deleted_rows > 100
      sleep 0.1
    end

    puts "Purged #{row_count} rows"
  end
end
