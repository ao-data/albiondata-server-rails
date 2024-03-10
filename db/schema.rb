# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_03_09_185749) do
  create_table "gold_prices", id: { type: :bigint, unsigned: true }, charset: "latin1", force: :cascade do |t|
    t.timestamp "timestamp"
    t.integer "price", unsigned: true
    t.index ["timestamp"], name: "idx_gold_prices_timestamp"
  end

  create_table "market_history", id: { type: :bigint, unsigned: true }, charset: "utf8mb4", force: :cascade do |t|
    t.bigint "item_amount", null: false, unsigned: true
    t.bigint "silver_amount", null: false, unsigned: true
    t.string "item_id", limit: 128, null: false
    t.integer "location", limit: 2, null: false, unsigned: true
    t.integer "quality", limit: 1, null: false, unsigned: true
    t.datetime "timestamp", null: false
    t.integer "aggregation", limit: 1, default: 6, null: false
    t.index ["aggregation", "timestamp"], name: "Aggregation"
    t.index ["item_id", "quality", "location", "timestamp", "aggregation"], name: "Main", unique: true
    t.index ["item_id", "timestamp", "aggregation"], name: "Simple"
  end

  create_table "market_orders", id: { type: :bigint, unsigned: true }, charset: "latin1", force: :cascade do |t|
    t.bigint "albion_id", null: false, unsigned: true
    t.string "item_id"
    t.integer "quality_level", limit: 1, unsigned: true
    t.integer "enchantment_level", limit: 1, unsigned: true
    t.bigint "price", unsigned: true
    t.integer "initial_amount", unsigned: true
    t.integer "amount", unsigned: true
    t.string "auction_type"
    t.timestamp "expires"
    t.integer "location", limit: 2, null: false, unsigned: true
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.timestamp "deleted_at"
    t.index ["albion_id"], name: "uix_market_orders_albion_id", unique: true
    t.index ["deleted_at", "expires", "updated_at"], name: "expired"
    t.index ["item_id", "location", "updated_at", "deleted_at"], name: "main"
  end

  create_table "market_orders_expired", id: { type: :bigint, unsigned: true }, charset: "latin1", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.bigint "albion_id", null: false, unsigned: true
    t.string "item_id"
    t.integer "quality_level", limit: 1, unsigned: true
    t.integer "enchantment_level", limit: 1, unsigned: true
    t.bigint "price", unsigned: true
    t.integer "initial_amount", unsigned: true
    t.integer "amount", unsigned: true
    t.string "auction_type"
    t.timestamp "expires"
    t.integer "location", limit: 2, null: false, unsigned: true
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.timestamp "deleted_at"
    t.index ["albion_id"], name: "uix_market_orders_expired_albion_id", unique: true
    t.index ["updated_at"], name: "updated_at_expired"
  end

  create_table "market_stats", id: { type: :bigint, unsigned: true }, charset: "latin1", force: :cascade do |t|
    t.string "item_id", null: false
    t.integer "location", limit: 2, null: false, unsigned: true
    t.bigint "price_min", unsigned: true
    t.bigint "price_max", unsigned: true
    t.decimal "price_avg", precision: 10
    t.timestamp "timestamp"
    t.index ["item_id", "location", "timestamp"], name: "item_id_location_timestamp_unique", unique: true
    t.index ["item_id"], name: "item_id"
    t.index ["location"], name: "location"
    t.index ["timestamp"], name: "timestamp"
  end

  create_table "users", charset: "utf8", force: :cascade do |t|
    t.string "username"
    t.string "email"
    t.string "crypted_password"
    t.string "password_salt"
    t.string "persistence_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
