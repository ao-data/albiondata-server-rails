require 'rails_helper'

RSpec.describe API::V2::Stats::GoldController, :type => :controller do
  describe "GET /gold" do
    let!(:gold_price) { create(:gold_price) }

    # before do
    #   create(:gold_price)
    # end

    context "when date and end_date parameters are not provided" do
      it "returns gold prices for the last month" do
        get :index, format: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq([
                                                  { "price" => gold_price.price / 10000, "timestamp" => gold_price.timestamp.strftime('%Y-%m-%dT%H:%M:%S') }
                                                ])
      end
    end

    context "when date and end_date parameters are provided" do
      let(:date) { Date.today - 1.month }
      let(:end_date) { Date.today }

      it "returns gold prices for the specified date range" do
        get :index, format: :json, params: { date: date.strftime('%m-%d-%Y'), end_date: end_date.strftime('%m-%d-%Y') }

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq([
                                                  { "price" => gold_price.price / 10000, "timestamp" => gold_price.timestamp.strftime('%Y-%m-%dT%H:%M:%S') }
                                                ])
      end
    end

    context "when date is provided but end_date is not" do
      let(:date) { Date.today - 1.month }

      it "returns gold prices from the specified date to one month later" do
        get :index, format: :json, params: { date: date.strftime('%m-%d-%Y') }

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq([
                                                  { "price" => gold_price.price / 10000, "timestamp" => gold_price.timestamp.strftime('%Y-%m-%dT%H:%M:%S') }
                                                ])
      end
    end

    context "when end_date is provided but date is not" do
      let(:end_date) { Date.today }

      it "returns gold prices from one month before the specified end_date to the end_date" do
        get :index, format: :json, params: { end_date: end_date.strftime('%m-%d-%Y') }

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq([
                                                  { "price" => gold_price.price / 10000, "timestamp" => gold_price.timestamp.strftime('%Y-%m-%dT%H:%M:%S') }
                                                ])
      end
    end

    context 'when there is gold data older than a month' do
      it 'does not return gold prices older than a month' do
        create(:gold_price, timestamp: 2.months.ago)

        get :index, format: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq([
                                                  { "price" => gold_price.price / 10000, "timestamp" => gold_price.timestamp.strftime('%Y-%m-%dT%H:%M:%S') }
                                                ])
      end
    end

    context 'when the request wants xml' do
      it 'returns the gold prices in xml format' do
        get :index, format: :xml

        expect(response).to have_http_status(:success)
        expect(response.body).to eq("<?xml version=\"1.0\"?>\n<ArrayOfGoldPrice xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\n  <GoldPrice>\n    <Id>#{gold_price.id}</Id>\n    <Price>#{gold_price.price / 10000}</Price>\n    <Timestamp>#{gold_price.timestamp.strftime('%Y-%m-%dT%H:%M:%S')}</Timestamp>\n  </GoldPrice>\n</ArrayOfGoldPrice>\n")
      end
    end
  end
end