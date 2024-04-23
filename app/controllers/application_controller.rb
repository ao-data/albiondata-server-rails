class ApplicationController < ActionController::Base
  around_action :run_using_database

  def test
    # this only here for spec testing run_using_database
    render json: { orders: MarketOrder.all }.to_json
  end

  def server_id
    request.subdomain
  end

  def run_using_database(&block)
    pp "using database #{request.subdomain}"
    Multidb.use(server_id, &block)
  end
end
