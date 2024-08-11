require 'rails_helper'

RSpec.describe API::V2::Stats::IdentifierController, :type => :controller do
  describe "GET /identifier" do

    context "when identifier parameter is not provided" do
      it "returns an error" do
        get :index, format: :json

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq({ "error" => "Identifier is required" })
      end
    end

    context "when identifier parameter is empty" do
      it "returns an error" do
        get :index, format: :json, params: { identifier: '' }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq({ "error" => "Identifier is required" })
      end
    end

    context "when identifier parameter is provided" do
      let(:identifier) { 'test_identifier' }
      let(:key) { "IDENTIFIER:#{identifier}" }

      before do
        REDIS['identifier'].del(key)
      end

      after do
        REDIS['identifier'].del(key)
      end

      it "returns the events associated with the identifier" do
        IdentifierService.add_identifier_event({ identifier: identifier }, 'test_event')

        get :index, format: :json, params: { identifier: identifier }

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq([
          { "timestamp" => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S'), "natsmsg" => nil, "event" => 'test_event' }
        ])
      end
    end

    context "when an error occurs" do
      it "returns an error" do
        allow(IdentifierService).to receive(:get_identifier_events).and_raise(StandardError.new('An error occurred'))

        get :index, format: :json, params: { identifier: 'test_identifier' }

        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)).to eq({ "error" => "Internal Server Error" })
      end
    end
  end
end
