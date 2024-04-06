require 'rails_helper'

RSpec.describe API::V2::Stats::PricesController, :type => :controller do
  let(:market_data_service) { instance_double(MarketDataService) }
  let(:sorted_results) { [{ item_id: 1, city: 'Thetford', quality: 'high', sell_price_min: 100, sell_price_min_date: '2022-01-01', sell_price_max: 200, sell_price_max_date: '2022-01-02', buy_price_min: 50, buy_price_min_date: '2022-01-03', buy_price_max: 150, buy_price_max_date: '2022-01-04' }] }

  before do
    allow(MarketDataService).to receive(:new).and_return(market_data_service)
    allow(market_data_service).to receive(:get_stats).and_return(sorted_results)
  end

  describe "GET #show" do
    context "when format is json" do
      it "returns market data as json" do
        get :show, format: :json, params: {id: 'T4_BAG'}

        expect(response).to have_http_status(:success)

        expect(JSON.parse(response.body)).to eq(sorted_results.map(&:deep_stringify_keys))
      end
    end

    context "when format is xml" do
      it "returns market data as xml" do
        get :show, format: :xml, params: {id: 'T4_BAG'}

        expect(response).to have_http_status(:success)
        expected_result = <<-EOD
<?xml version="1.0"?>
<ArrayOfMarketResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <MarketResponse>
    <ItemTypeId>1</ItemTypeId>
    <City>Thetford</City>
    <QualityLevel>high</QualityLevel>
    <SellPriceMin>100</SellPriceMin>
    <SellPriceMinDate>2022-01-01</SellPriceMinDate>
    <SellPriceMax>200</SellPriceMax>
    <SellPriceMaxDate>2022-01-02</SellPriceMaxDate>
    <BuyPriceMin>50</BuyPriceMin>
    <BuyPriceMinDate>2022-01-03</BuyPriceMinDate>
    <BuyPriceMax>150</BuyPriceMax>
    <BuyPriceMaxDate>2022-01-04</BuyPriceMaxDate>
  </MarketResponse>
</ArrayOfMarketResponse>
EOD
        expect(response.body).to eq(expected_result)
      end
    end

    context "when service raises an error" do
      it "returns a 500 status code" do
        allow(market_data_service).to receive(:get_stats).and_raise(StandardError)

        get :show, format: :json, params: {id: 'T4_BAG'}

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
