require 'rails_helper'

RSpec.describe PowController, :type => :controller do
  before do
    @request.host = "west.example.com"
  end

  describe 'GET #index' do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end

    it 'returns a json response' do
      get :index
      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    it 'returns a json object with the keys wanted and key' do
      get :index
      expect(JSON.parse(response.body).keys).to eq(['wanted', 'key'])
    end

    it 'stores the challenge in redis' do
      # todo: fill this test in with a more specific expectation
      expect(REDIS['west']).to receive(:set).and_call_original

      get :index
    end
  end

  describe 'POST #reply' do
    let(:pow) { { wanted: '0011', key: 'pow_key' } }
    let(:params) { { topic: 'marketorders.ingest', key: 'pow_key', solution: '0011',
                     natsmsg: { Orders: [] }.to_json , identifier: 'test_identifier' } }

    before do
      REDIS['west'].set('POW:pow_key', pow.to_json)
      allow(controller).to receive(:supported_client?).and_return(true)
      allow(controller).to receive(:ip_good?).and_return(true)
    end

    it 'returns a success response' do
      post :reply, params: params
      expect(response).to be_successful
    end

    # remove this test for now
    xit 'returns a 905 error if the client is not supported' do
      allow(controller).to receive(:supported_client?).and_return(false)
      post :reply, params: params
      expect(response.status).to eq(905)
    end

    it 'returns a 404 error if the topic is not found' do
      post :reply, params: params.merge(topic: 'notfound')
      expect(response.status).to eq(404)
    end

    it 'returns a 902 error if the pow was never requested or has expired' do
      REDIS['west'].del('POW:pow_key')
      post :reply, params: params
      expect(response.status).to eq(902)
    end

    it 'returns a 903 error if the pow was not solved correctly' do
      post :reply, params: params.merge(solution: '0000')
      expect(response.status).to eq(903)
    end

    it 'returns a 904 error if the payload is too large' do
      post :reply, params: params.merge(natsmsg: { Orders: [1]*100 }.to_json)
      expect(response.status).to eq(904)
    end

    it 'returns a 901 error if the JSON data is invalid' do
      post :reply, params: params.merge(natsmsg: 'invalid')
      expect(response.status).to eq(901)
    end

    context 'when the topic is marketorders.ingest' do
      let(:params) { { topic: 'marketorders.ingest', key: 'pow_key', solution: '0011', natsmsg: { Orders: [] }.to_json } }

      it 'returns a 904 error if there are more than 50 orders' do
        post :reply, params: params.merge(natsmsg: { Orders: [1]*51 }.to_json)
        expect(response.status).to eq(904)
      end
    end

    context 'when the topic is goldprices.ingest' do
      let(:params) { { topic: 'goldprices.ingest', key: 'pow_key', solution: '0011', natsmsg: { Prices: [] }.to_json } }

      it 'returns a 904 error if there are more than 673 prices' do
        post :reply, params: params.merge(natsmsg: { Prices: [1]*674 }.to_json)
        expect(response.status).to eq(904)
      end
    end

    context 'when the topic is markethistories.ingest' do
      let(:params) { { topic: 'markethistories.ingest', key: 'pow_key', solution: '0011', natsmsg: { Timescale: 0, MarketHistories: [] }.to_json } }

      it 'returns a 904 error if there are more than 25 MarketHistories with Timescale 0' do
        post :reply, params: params.merge(natsmsg: { Timescale: 0, MarketHistories: [1]*26 }.to_json)
        expect(response.status).to eq(904)
      end

      it 'returns a 904 error if there are more than 29 MarketHistories with Timescale 1' do
        post :reply, params: params.merge(natsmsg: { Timescale: 1, MarketHistories: [1]*30 }.to_json)
        expect(response.status).to eq(904)
      end

      it 'returns a 904 error if there are more than 113 MarketHistories with Timescale 2' do
        post :reply, params: params.merge(natsmsg: { Timescale: 2, MarketHistories: [1]*114 }.to_json)
        expect(response.status).to eq(904)
      end
    end

    it 'does process data if the ip is good' do
      allow(controller).to receive(:ip_good?).and_return(true)
      opts = { client_ip: '0.0.0.0', user_agent: 'Rails Testing', identifier: 'test_identifier' }.to_json
      expect(controller).to receive(:enqueue_worker).with('marketorders.ingest', { 'Orders' => [] }.to_json, 'west', opts)
      post :reply, params: params
    end

    it 'does not process data if ip is bad' do
      allow(controller).to receive(:ip_good?).and_return(false)
      expect(controller).not_to receive(:enqueue_worker)
      post :reply, params: params
    end

    it 'sets the user agent to unknown if there is no user agent present' do
      @request.user_agent = nil
      opts = { client_ip: '0.0.0.0', user_agent: 'unknown', identifier: 'test_identifier' }.to_json
      expect(controller).to receive(:enqueue_worker).with('marketorders.ingest', { 'Orders' => [] }.to_json, 'west', opts)
      post :reply, params: params
    end

    it 'sets the identifier to a new uuid if identifier is not present' do
      opts = { client_ip: '0.0.0.0', user_agent: 'Rails Testing', identifier: 'new_uuid' }.to_json
      expect(SecureRandom).to receive(:uuid).and_return('new_uuid')
      expect(controller).to receive(:enqueue_worker).with('marketorders.ingest', { 'Orders' => [] }.to_json, 'west', opts)
      post :reply, params: params.except(:identifier)
    end

    xit 'logs the request' do

    end
  end

  describe 'enqueue_worker' do
    let (:opts) { { client_ip: '0.0.0.0', user_agent: 'Rails Testing', identifier: 'test_identifier' } }

    it 'enqueues a GoldPriceDedupeWorker if the topic is goldprices.ingest' do
      expect(GoldDedupeWorker).to receive(:perform_async).with({}, 'west', opts)
      controller.enqueue_worker('goldprices.ingest', {}, 'west', opts)
    end

    it 'enqueues a MarketOrderDedupeWorker if the topic is marketorders.ingest' do
      expect(MarketOrderDedupeWorker).to receive(:perform_async).with({}, 'west', opts)
      controller.enqueue_worker('marketorders.ingest', {}, 'west', opts)
    end

    it 'enqueues a MarketHistoryDedupeWorker if the topic is markethistories.ingest' do
      expect(MarketHistoryDedupeWorker).to receive(:perform_async).with({}, 'west', opts)
      controller.enqueue_worker('markethistories.ingest', {}, 'west', opts)
    end

    it 'enqueues a MarketHistoryDedupeWorker if the topic is markethistories.ingest for east database' do
      @request.host = 'east.example.com'
      expect(MarketHistoryDedupeWorker).to receive(:perform_async).with({}, 'east', opts)
      controller.enqueue_worker('markethistories.ingest', {}, 'east', opts)
    end

    # xit 'enqueues a MapDataDedupeWorker if the topic is mapdata.ingest' do
    #   expect(MapDataDedupeWorker).to receive(:perform_async).with({})
    #   controller.enqueue_worker('mapdata.ingest', {})
    # end
  end

  describe '#supported_client?' do
    it 'returns true if there are no supported clients' do
      REDIS['west'].del('supported_clients')
      expect(controller.supported_client?).to be(true)
    end

    it 'returns true if the user agent is in the supported clients' do
      REDIS['west'].set('supported_clients', ['Mozilla'])
      request.env['HTTP_USER_AGENT'] = 'Mozilla'
      expect(controller.supported_client?).to be(true)
    end

    it 'returns false if the user agent is not in the supported clients' do
      REDIS['west'].set('supported_clients', ['Mozilla'])
      request.env['HTTP_USER_AGENT'] = 'Chrome'
      expect(controller.supported_client?).to be(false)
    end
  end

  describe '#ip_good?' do
    it 'returns true if the ip is good' do
      allow_any_instance_of(Ipdb).to receive(:check_ip).and_return(true)
      expect(controller.ip_good?).to be(true)
    end

    it 'returns false if the ip is bad' do
      allow_any_instance_of(Ipdb).to receive(:check_ip).and_return(false)
      expect(controller.ip_good?).to be(false)
    end
  end
end