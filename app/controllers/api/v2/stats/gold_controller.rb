class API::V2::Stats::GoldController < API::V2::APIController

  def index
    if params.key?(:date)
      date_from = Date.strptime(params[:date], '%m-%d-%Y')
    else
      date_from = DateTime.now - 1.month
    end

    if params.key?(:end_date)
      date_to = Date.strptime(params[:end_date], '%m-%d-%Y')
    else
      date_to = date_from + 1.month
    end

    results = []
    GoldPrice.where(timestamp: date_from..date_to).order(:timestamp).each do |row|
      results << { price: row[:price] / 10000, timestamp: row[:timestamp].strftime('%Y-%m-%dT%H:%M:%S') }
    end


    render json: results
  end

end
