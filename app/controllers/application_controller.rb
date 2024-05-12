class ApplicationController < ActionController::Base
  around_action :run_using_database

  def test
    # this only here for spec testing run_using_database
    render json: { orders: MarketOrder.all.limit(10) }.to_json
  end

  def server_id
    request.subdomain.split('.').last
  end

  def run_using_database(&block)
    logger.info("using database #{request.subdomain}")
    Multidb.use(server_id, &block)
  end
end
