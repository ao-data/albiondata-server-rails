require 'rails_helper'

RSpec.describe 'GET /api/v2/stats/history and /api/v2/stats/charts', type: :request do
  let(:market_history_service) { instance_double(MarketHistoryService) }

  before do
    Timecop.freeze(DateTime.parse('2024-03-10 00:00:00'))
  end

  after do
    Timecop.return
  end

  describe 'GET /api/v2/stats/history/:id' do
    let(:results) { [{ location: 'location', item_id: 1, quality: 'high', data: [{ item_count: 10, avg_price: 100, timestamp: '2022-01-01' }] }] }

    before do
      allow(MarketHistoryService).to receive(:new).and_return(market_history_service)
      allow(market_history_service).to receive(:get_stats).and_return(results)
    end

    context 'when format is json' do
      it 'returns market history as json' do
        get '/api/v2/stats/history/T4_BAG'

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq(results.map(&:deep_stringify_keys))
      end
    end

    context 'when format is xml' do
      it 'returns market history as xml' do
        get '/api/v2/stats/history/T4_BAG.xml'

        expect(response).to have_http_status(:success)
        expected_result = <<-EOD
<?xml version="1.0"?>
<ArrayOfMarketHistoriesResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <MarketHistoriesResponse>
    <Location>location</Location>
    <ItemTypeId>1</ItemTypeId>
    <QualityLevel>high</QualityLevel>
    <Data>
      <MarketHistoryResponse>
        <ItemCount>10</ItemCount>
        <AveragePrice>100</AveragePrice>
        <Timestamp>2022-01-01</Timestamp>
      </MarketHistoryResponse>
    </Data>
  </MarketHistoriesResponse>
</ArrayOfMarketHistoriesResponse>
        EOD
        expect(response.body).to eq(expected_result)
      end

      it 'returns a Content-Type header with an explicit charset' do
        get '/api/v2/stats/history/T4_BAG.xml'

        expect(response.headers['Content-Type']).to eq('application/xml; charset=utf-8')
      end
    end

    context 'when service raises an error' do
      it 'returns a 500 status code' do
        allow(market_history_service).to receive(:get_stats).and_raise(StandardError)

        get '/api/v2/stats/history/T4_BAG'

        expect(response).to have_http_status(:internal_server_error)
      end
    end

    context 'when locations is passed as an array-style query param' do
      it 'returns market history as json' do
        get '/api/v2/stats/history/T4_BAG', params: { locations: ['Caerleon', 'Martlock'] }

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq(results.map(&:deep_stringify_keys))
      end
    end
  end

  describe 'GET /api/v2/stats/charts/:id' do
    let(:results) { [{"location":"Caerleon","item_id":"T4_BAG","quality":1,"data":{"timestamps":["2024-03-09T00:00:00","2024-03-10T00:00:00"],"prices_avg":[10,10],"item_count":[20,10]}},{"location":"Caerleon","item_id":"T4_BAG","quality":2,"data":{"timestamps":["2024-03-09T00:00:00","2024-03-10T00:00:00"],"prices_avg":[10,10],"item_count":[20,10]}}] }

    before do
      allow(MarketHistoryService).to receive(:new).and_return(market_history_service)
      allow(market_history_service).to receive(:get_charts).and_return(results)
    end

    context 'when format is json' do
      it 'returns market history as json' do
        get '/api/v2/stats/charts/T4_BAG'

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq(results.map(&:deep_stringify_keys))
      end
    end

    context 'when format is xml' do
      it 'returns market history as xml' do
        get '/api/v2/stats/charts/T4_BAG.xml'

        expect(response).to have_http_status(:success)
        expected_result = <<-EOD
<?xml version="1.0"?>
<ArrayOfMarketStatChartResponsev2 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <MarketStatChartResponsev2>
    <Location>Caerleon</Location>
    <ItemTypeId>T4_BAG</ItemTypeId>
    <QualityLevel>1</QualityLevel>
    <Data>
      <Timestamps>
        <dateTime>2024-03-09T00:00:00</dateTime>
        <dateTime>2024-03-10T00:00:00</dateTime>
      </Timestamps>
      <PricesAverage>
        <decimal>10</decimal>
        <decimal>10</decimal>
      </PricesAverage>
      <ItemCount>
        <unsignedLong>20</unsignedLong>
        <unsignedLong>10</unsignedLong>
      </ItemCount>
    </Data>
  </MarketStatChartResponsev2>
  <MarketStatChartResponsev2>
    <Location>Caerleon</Location>
    <ItemTypeId>T4_BAG</ItemTypeId>
    <QualityLevel>2</QualityLevel>
    <Data>
      <Timestamps>
        <dateTime>2024-03-09T00:00:00</dateTime>
        <dateTime>2024-03-10T00:00:00</dateTime>
      </Timestamps>
      <PricesAverage>
        <decimal>10</decimal>
        <decimal>10</decimal>
      </PricesAverage>
      <ItemCount>
        <unsignedLong>20</unsignedLong>
        <unsignedLong>10</unsignedLong>
      </ItemCount>
    </Data>
  </MarketStatChartResponsev2>
</ArrayOfMarketStatChartResponsev2>
        EOD

        expect(response.body).to eq(expected_result)
      end
    end

    context 'when qualities is passed as an array-style query param' do
      it 'returns market history as json' do
        get '/api/v2/stats/charts/T4_BAG', params: { qualities: %w[1 2] }

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq(results.map(&:deep_stringify_keys))
      end
    end
  end
end
