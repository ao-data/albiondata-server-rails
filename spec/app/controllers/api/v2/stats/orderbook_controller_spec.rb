require 'rails_helper'

RSpec.describe API::V2::Stats::OrderbookController, :type => :controller do
  let(:market_orderbook_service) { instance_double(MarketOrderbookService) }
  let(:sorted_results) { [{ item_id: 'T4_BAG', city: 'Caerleon', quality: 1, sell: [{ price: 5928, amount: 40, updated_at: '2024-03-09T09:04:00' }, { price: 6100, amount: 12, updated_at: '2024-03-09T09:02:00' }], buy: [{ price: 5000, amount: 5, updated_at: '2024-03-09T08:59:00' }] }] }

  before do
    allow(MarketOrderbookService).to receive(:new).and_return(market_orderbook_service)
    allow(market_orderbook_service).to receive(:get_orderbook).and_return(sorted_results)
  end

  describe "GET #show" do
    context "when format is json" do
      it "returns order books as json" do
        get :show, format: :json, params: {id: 'T4_BAG'}

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq(sorted_results.map(&:deep_stringify_keys))
      end
    end

    context "when format is xml" do
      it "returns order books as xml" do
        get :show, format: :xml, params: {id: 'T4_BAG'}

        expect(response).to have_http_status(:success)
        expected_result = <<-EOD
<?xml version="1.0"?>
<ArrayOfOrderbookResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <OrderbookResponse>
    <ItemTypeId>T4_BAG</ItemTypeId>
    <City>Caerleon</City>
    <QualityLevel>1</QualityLevel>
    <Sell>
      <OrderLevel>
        <Price>5928</Price>
        <Amount>40</Amount>
        <UpdatedAt>2024-03-09T09:04:00</UpdatedAt>
      </OrderLevel>
      <OrderLevel>
        <Price>6100</Price>
        <Amount>12</Amount>
        <UpdatedAt>2024-03-09T09:02:00</UpdatedAt>
      </OrderLevel>
    </Sell>
    <Buy>
      <OrderLevel>
        <Price>5000</Price>
        <Amount>5</Amount>
        <UpdatedAt>2024-03-09T08:59:00</UpdatedAt>
      </OrderLevel>
    </Buy>
  </OrderbookResponse>
</ArrayOfOrderbookResponse>
        EOD
        expect(response.body).to eq(expected_result)
      end
    end

    context "when service raises an error" do
      it "returns a 500 status code" do
        allow(market_orderbook_service).to receive(:get_orderbook).and_raise(StandardError)

        get :show, format: :json, params: {id: 'T4_BAG'}

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
