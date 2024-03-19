class API::V2::Stats::GoldController < API::V2::APIController

  def index
    date_from = params.key?(:date) ? Date.strptime(params[:date], '%m-%d-%Y') : DateTime.now - 1.month
    date_to = params.key?(:end_date) ? Date.strptime(params[:end_date], '%m-%d-%Y') : date_from + 1.month

    results = GoldPrice.where(timestamp: date_from..date_to).order(timestamp: :desc).map do |row|
      { price: row[:price] / 10000, timestamp: row[:timestamp].strftime('%Y-%m-%dT%H:%M:%S') }
    end

    render json: results
  end
end
