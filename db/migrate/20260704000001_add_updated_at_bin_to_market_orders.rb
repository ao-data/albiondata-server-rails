class AddUpdatedAtBinToMarketOrders < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL
      ALTER TABLE market_orders
        ADD COLUMN updated_at_bin INT UNSIGNED GENERATED ALWAYS AS
        (UNIX_TIMESTAMP(updated_at) DIV 300 * 300) STORED
    SQL

    add_index :market_orders, [:item_id, :location, :quality_level, :auction_type, :updated_at_bin], name: 'stats_bin'
  end

  def down
    remove_index :market_orders, name: 'stats_bin'
    remove_column :market_orders, :updated_at_bin
  end
end
