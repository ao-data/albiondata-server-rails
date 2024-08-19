require 'rails_helper'

RSpec.describe API::V2::Stats::IdentifierController, :type => :controller do
  describe "GET #index" do

    context "when identifier parameter is empty" do
      it "returns an error" do
        get :index, params: { identifier: '' }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq({ "error" => "Identifier is required" })
      end
    end

    context "when identifier parameter is provided" do
      let(:identifier) { 'test_identifier' }
      let(:server_id) { 'test_server' }
      let(:other_server_id) { 'other_server' }
      let(:key) { "IDENTIFIER:#{server_id}:#{identifier}" }
      let(:other_key) { "IDENTIFIER:#{other_server_id}:#{identifier}" }

      before do
        allow(controller).to receive(:server_id).and_return(server_id)
        REDIS['identifier'].del(key)
        REDIS['identifier'].del(other_key)
      end

      after do
        REDIS['identifier'].del(key)
        REDIS['identifier'].del(other_key)
      end

      it "returns only the events associated with the identifier and the set server" do
        IdentifierService.add_identifier_event({ identifier: identifier }, server_id, 'event1')
        IdentifierService.add_identifier_event({ identifier: identifier }, other_server_id, 'event2')

        get :index, params: { identifier: identifier }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([{ "server" => server_id, "timestamp" => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S'), "event" => 'event1', "natsmsg" => nil }])
      end

      it "returns an empty array if no events are associated with the identifier" do
        get :index, params: { identifier: identifier }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end
    end

    context "when an error occurs" do
      it "returns an error" do
        allow(IdentifierService).to receive(:get_identifier_events).and_raise(StandardError.new('An error occurred'))

        get :index, params: { identifier: 'test_identifier' }

        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)).to eq({ "error" => "Internal Server Error" })
      end
    end
  end
end
