class PowController < ApplicationController
  skip_before_action :verify_authenticity_token

  TOPICS = %w(goldprices.ingest marketorders.ingest markethistories.ingest mapdata.ingest)
  NATS_URI = ENV['NATS_URI']

  # Each ingestion takes 2 REQUEST
  # get pow
  # submit pow & ingestion
  REQUEST_LIMIT = {
    per_day: 30_000 * 2,
    per_hour: 3_000 * 2,
    per_minute: 270 * 2,
  }

  # Number of handed pows to remember (prevents out of memory)
  POW_KEEP = 10_000

  # Higher difficulity will take the client more time to solve
  # Benchmark: https://docs.google.com/spreadsheets/d/1aongAIvJs0idA9ABk_saGIyeyvZJL9glxf1vsaCO5MY/edit?usp=sharing
  POW_DIFFICULITY =  ENV['POW_DIFFICULITY'].nil? ? 39 : ENV['POW_DIFFICULITY'].to_i

  # Limits the size of a nats payload
  # 32768 should be large enough for any corrctly functioning client
  NATS_PAYLOAD_MAX =  ENV['NATS_PAYLOAD_MAX'].nil? ? 32768 : ENV['NATS_PAYLOAD_MAX'].to_i

  # Higher randomness will make it harder to store all possible combinations
  # If it is to low the pows can be pre-solved, stored and lookedup as needed
  # Formular for possible combinations: (POW_RANDOMNESS^16)*(POW_DIFFICULITY^2)
  # e.g.: (8^16)*(32^2) = 288,230,376,151,711,744 (~ two hundred eighty-eight quadrillion)
  #       (3^16)*(32^2) = 44,079,842,304          (~ forty-four billion)
  POW_RANDOMNESS=3

  POW_EXPIRE_SECONDS = ENV['POW_EXPIRE_SECONDS'].nil? ? 32768 : ENV['POW_EXPIRE_SECONDS'].to_i

  def initialize
    super
  end

  def index
    challange = { wanted: SecureRandom.hex(POW_RANDOMNESS).unpack("B*")[0][0..POW_DIFFICULITY-1], key: SecureRandom.hex(POW_RANDOMNESS) }
    REDIS[server_id].set("POW:#{challange[:key]}", {wanted: challange[:wanted]}.to_json, ex: POW_EXPIRE_SECONDS)
    render json: challange.to_json
  end

  def reply
    pow_json = REDIS[server_id].get("POW:#{params[:key]}")
    REDIS[server_id].del("POW:#{params[:key]}")
    return render plain: "Pow not handed", status: 902 unless pow_json # This pow was never requested or has expired
    pow = JSON.parse(pow_json)

    return render plain: "Unsupported data client.", status: 905 unless supported_client?
    return render plain: "Topic not found.", status: 404 unless TOPICS.include?(params[:topic])
    return render plain: "Pow not solved correctly", status: 903 unless Digest::SHA2.hexdigest("aod^" + params[:solution] + "^" + params[:key]).unpack("B*")[0].start_with?(pow['wanted'])
    return render plain: "Payload too large", status: 904 unless params[:natsmsg].bytesize <= NATS_PAYLOAD_MAX

    begin
      data = JSON.parse(params[:natsmsg])
    rescue
      return render plain: "Invalid JSON data", status: 901
    end

    if params[:topic] == "marketorders.ingest" && data['Orders'].count > 50
      logger.warn("Error 904, Too Much Data. ip: #{request.ip}, topic: marketorders.ingest, order count: #{data['Orders'].count}")
      return render plain: "Too much data", status: 904
    end

    if params[:topic] == "goldprices.ingest" && data['Prices'].count > 673
      logger.warn("Error 904, Too Much Data. ip: #{request.ip}, topic: goldprices.ingest, order count: #{data['Prices'].count}")
      return render plain: "Too much data", status: 904
    end

    if params[:topic] == "markethistories.ingest"
      failed = false

      failed = true if data['Timescale'] == 0 && data['MarketHistories'].count > 25
      failed = true if data['Timescale'] == 1 && data['MarketHistories'].count > 29
      failed = true if data['Timescale'] == 2 && data['MarketHistories'].count > 113


      if failed == true
        logger.warn("Error 904, Too Much Data. ip: #{request.ip}, topic: markethistories.ingest, Timescale: #{data['Timescale']}, MarketHistories count: #{data['MarketHistories'].count}")
        return render plain: "Too much data", status: 904
      end
    end

    log_params = params.merge({request_ip: request.ip, user_agent: request.env['HTTP_USER_AGENT']})
    if ip_good?

      enqueue_worker(params[:topic], params[:natsmsg], server_id)

      logger.info(log_params.to_json) if ENV['DEBUG'] == "true"
    else
      logger.warn(log_params.merge({bad_ip: true}).to_json) if ENV['DEBUG'] == "true"
    end

    render json: { message: "OK", status: 200 }
  end

  def enqueue_worker(topic, data, server_id)
    case topic.downcase
    when "goldprices.ingest"
      GoldDedupeWorker.perform_async(data, server_id)
    when "marketorders.ingest"
      MarketOrderDedupeWorker.perform_async(data, server_id)
    when "markethistories.ingest"
      MarketHistoryDedupeWorker.perform_async(data, server_id)
    # when "mapdata.ingest"
    #   MapDataDedupeWorker.perform_async(data)
    end
  end

  def supported_client?
    if (supported_clients_json = REDIS[server_id].get('supported_clients'))
      supported_clients = JSON.parse(supported_clients_json)
      return false if !supported_clients.empty? && !supported_clients.include?(request.env['HTTP_USER_AGENT'])
    end

    true
  end

  def ip_good?
    ipdb = Ipdb.new
    ipdb.check_ip(request.ip)
  end

end
