class API::V2::Stats::IdentifierController < API::V2::APIController

  def index
    begin
      logger.info("multidb_info: server_id: #{server_id}, database: #{Multidb.balancer.current_connection.raw_connection.connection_options[:database]}")

      identifier = params[:identifier]

      puts "IDENTIFIER:#{identifier}"

      response = REDIS['identifier'].lrange("IDENTIFIER:#{identifier}", 0, -1)

      parsed_response = response.map { |json_str| JSON.parse(json_str) }

      respond_to do |format|
        format.xml { render xml: parsed_response.to_xml }
        format.json { render json: parsed_response.to_json }
      end
    rescue StandardError => e
      logger.error({location: 'API::V2::Stats::IdentifierController.index', message: e.message, backtrace: e.backtrace, params: params, query_string: request.query_string})
      render json: { error: 'Internal Server Error' }, status: :internal_server_error
    end
  end

end
