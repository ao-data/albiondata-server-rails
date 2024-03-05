class API::V2::StatsController < API::V2::APIController
  def index
    pp params
    render json: '{"meh":"asdf"}'
  end

  def show
    ids = params[:id].split(',')
    locations = params[:locations].split(',') if params.key?(:locations)
    qualities = params[:qualities].split(',') if params.key?(:qualities)

    orders = MarketOrder.where(item_id: ids, updated_at: 1.days.ago..)
    orders = orders.where(location: locations) if locations
    orders = orders.where(quality_level: qualities) if qualities
    orders = orders.select(:item_id, :location, :auction_type, :quality_level, :price, :updated_at)
    orders = orders.order(item_id: :asc, updated_at: :asc, location: :asc, quality_level: :asc)

    results = {}
    last_groups = {}

    counter = 0
    pp DateTime.now

    orders.each do |order|
      pp DateTime.now if counter == 0
      counter += 1

      o_key = "##{order[:item_id]}_#{order[:location]}_#{order[:quality_level]}"

      if results.key?(o_key)
        result = results[o_key]
      else
        result = default_result
        result[:item_id] = order[:item_id]
        result[:city] = order[:location]
        result[:quality] = order[:quality_level]
        results[o_key] = result
      end

      dt = order[:updated_at]
      this_group = DateTime.new(dt.year, dt.month, dt.day, dt.hour, dt.to_datetime.minute - (dt.to_datetime.minute % 5), 0)

      last_groups[o_key] = DateTime.new(2000, 1, 1, 0, 0, 0) unless last_groups.key?(o_key)

      if this_group > last_groups[o_key]
        last_groups[o_key] = this_group

        if order[:auction_type] == 'offer'
          results[o_key][:sell_price_min] = 999999999999
          results[o_key][:sell_price_min_date] = nil
          results[o_key][:sell_price_max] = 0
          results[o_key][:sell_price_max_date] = nil
        elsif order[:auction_type] == 'request'
          results[o_key][:buy_price_min] = 999999999999
          results[o_key][:buy_price_min_date] = nil
          results[o_key][:buy_price_max] = 0
          results[o_key][:buy_price_max_date] = nil
        end
      end


      if order[:auction_type] == 'offer'
        # sell
        if order[:price] < results[o_key][:sell_price_min]
          results[o_key][:sell_price_min] = order[:price]
          results[o_key][:sell_price_min_date] = this_group
        end

        if order[:price] > results[o_key][:sell_price_max]
          results[o_key][:sell_price_max] = order[:price]
          results[o_key][:sell_price_max_date] = this_group
        end

      elsif order[:auction_type] == 'request'
        # buy
        if order[:price] < results[o_key][:buy_price_min]
          results[o_key][:buy_price_min] = order[:price]
          results[o_key][:buy_price_min_date] = this_group
        end

        if order[:price] > results[o_key][:buy_price_max]
          results[o_key][:buy_price_max] = order[:price]
          results[o_key][:buy_price_max_date] = this_group
        end
      end

    end
    pp DateTime.now
    pp counter

    render json: results
  end

  def default_result
    {
      item_id: nil,
      city: nil,
      quality: nil,
      sell_price_min: 999999999999,
      sell_price_min_date: nil,
      sell_price_max: 0,
      sell_price_max_date: nil,
      buy_price_min: 999999999999,
      buy_price_min_date: nil,
      buy_price_max: 0,
      buy_price_max_date: nil,
    }
  end

end
