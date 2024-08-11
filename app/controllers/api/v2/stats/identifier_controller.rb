class API::V2::Stats::IdentifierController < ActionController::Base
  def index
    begin
      identifier = params[:identifier]

      if identifier.nil? or identifier.empty?
        render json: { error: 'Identifier is required' }, status: :bad_request
        return
      end

      response = IdentifierService.get_identifier_events(identifier)

      respond_to do |format|
        format.xml { render xml: response.to_xml }
        format.json { render json: response.to_json }
      end
    rescue StandardError => e
      logger.error({location: 'API::V2::Stats::IdentifierController.index', message: e.message, backtrace: e.backtrace, params: params, query_string: request.query_string})
      render json: { error: 'Internal Server Error' }, status: :internal_server_error
    end
  end

end
