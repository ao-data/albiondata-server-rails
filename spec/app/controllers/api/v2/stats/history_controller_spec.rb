require 'rails_helper'

RSpec.describe API::V2::Stats::HistoryController, :type => :controller do
  let(:market_history_service) { instance_double(MarketHistoryService) }
  let(:results) { [{ location: 'location', item_id: 1, quality: 'high', data: [{ item_count: 10, avg_price: 100, timestamp: '2022-01-01' }] }] }

  before do
    allow(MarketHistoryService).to receive(:new).and_return(market_history_service)
    allow(market_history_service).to receive(:get_stats).and_return(results)
  end

  describe "GET #show" do
    context "when format is json" do
      it "returns market history as json" do
        get :show, format: :json, params: {id: 'T4_BAG'}

        expect(response).to have_http_status(:success)

        expect(JSON.parse(response.body)).to eq(results.map(&:deep_stringify_keys))
      end
    end

    context "when format is xml" do
      it "returns market history as xml" do
        get :show, format: :xml, params: {id: 'T4_BAG'}

        expect(response).to have_http_status(:success)
        puts response.body
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
    end

    context "when service raises an error" do
      it "returns a 500 status code" do
        allow(market_history_service).to receive(:get_stats).and_raise(StandardError)

        get :show, format: :json, params: {id: 'T4_BAG'}

        # 0) API::V2::Stats::HistoryController GET #show when service raises an error returns a 500 status code
        # Failure/Error: results = MarketHistoryService.new.get_stats(params.merge({ query_string: request.query_string}))
        #
        # StandardError:
        #   StandardError
        # # ./app/controllers/api/v2/stats/history_controller.rb:5:in `show'
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end