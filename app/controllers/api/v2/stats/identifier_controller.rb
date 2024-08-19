class API::V2::Stats::IdentifierController < API::V2::APIController
  def index
    begin
      if params[:identifier].nil? or params[:identifier].empty?
        render json: { error: 'Identifier is required' }, status: :bad_request
        return
      end

      response = IdentifierService.get_identifier_events(params[:identifier], server_id)

      render json: response.to_json
    rescue StandardError => e
      logger.error({location: 'API::V2::Stats::IdentifierController.index', message: e.message, backtrace: e.backtrace, params: params, query_string: request.query_string})
      render json: { error: 'Internal Server Error' }, status: :internal_server_error
    end
  end

end
