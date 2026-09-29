class AddOrderbookIndexToMarketOrders < ActiveRecord::Migration[7.1]
  def change
    add_index :market_orders, [:item_id, :location, :quality_level, :auction_type, :price], name: 'orderbook'
  end
end
