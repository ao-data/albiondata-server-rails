class API::V2::Stats::FestivitiesController < API::V2::APIController
  def index
    snapshot = REDIS[server_id].get(FestivitiesService::CURRENT_SNAPSHOT_KEY)
    if snapshot.nil?
      render json: { error: 'No confirmed festivities snapshot' }, status: :not_found
      return
    end

    response.headers['Cache-Control'] = 'public, max-age=60, stale-while-revalidate=300'
    render json: JSON.parse(snapshot)
  rescue StandardError => e
    logger.error({location: 'API::V2::Stats::FestivitiesController.index', message: e.message, backtrace: e.backtrace, params: params, query_string: request.query_string})
    render json: { error: 'Internal Server Error' }, status: :internal_server_error
  end
end
