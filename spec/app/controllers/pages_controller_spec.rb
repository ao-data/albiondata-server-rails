# frozen_string_literal: true

require "rails_helper"

RSpec.describe PagesController, type: :controller do
  describe "GET #index" do
    it "returns a success response" do
      get :index
      expect(response).to be_successful
    end
  end

  describe "GET #faq" do
    it "returns a success response" do
      get :faq
      expect(response).to be_successful
    end
  end

  describe "GET #api" do
    it "returns a success response" do
      get :api
      expect(response).to be_successful
    end
  end

  describe "GET #client" do
    let(:stats_result) do
      GithubReleaseStatsService::Result.new(
        total_downloads: 100,
        latest_release_tag: "v1.0.0",
        latest_release_downloads: 50,
        latest_downloads_by_os: { "Windows" => 30, "macOS" => 20 },
        latest_downloads_by_type: { "Full install" => 50 },
        downloads_by_os: { "Windows" => 60, "macOS" => 40 },
        downloads_by_type: { "Full install" => 100 },
        error: nil
      )
    end

    before do
      allow(GithubReleaseStatsService).to receive(:call).and_return(stats_result)
    end

    it "returns a success response" do
      get :client
      expect(response).to be_successful
    end

    it "calls GithubReleaseStatsService.call and assigns result to @client_download_stats" do
      get :client
      expect(GithubReleaseStatsService).to have_received(:call)
      expect(assigns(:client_download_stats)).to eq(stats_result)
    end
  end

  describe "GET #identifier" do
    context "when identifier is provided" do
      let(:identifier) { "abc-123" }
      let(:west_events) { [{ "server" => "west", "timestamp" => "2024-01-02T10:00:00", "event" => "login" }] }
      let(:east_events) { [{ "server" => "east", "timestamp" => "2024-01-01T09:00:00", "event" => "login" }] }
      let(:europe_events) { [] }

      before do
        allow(IdentifierService).to receive(:get_identifier_events).with(identifier, "west").and_return(west_events)
        allow(IdentifierService).to receive(:get_identifier_events).with(identifier, "east").and_return(east_events)
        allow(IdentifierService).to receive(:get_identifier_events).with(identifier, "europe").and_return(europe_events)
      end

      it "returns a success response" do
        get :identifier, params: { identifier: identifier }
        expect(response).to be_successful
      end

      it "assigns @identifier from params[:identifier]" do
        get :identifier, params: { identifier: identifier }
        expect(assigns(:identifier)).to eq(identifier)
      end

      it "calls IdentifierService.get_identifier_events for west, east, and europe" do
        get :identifier, params: { identifier: identifier }

        expect(IdentifierService).to have_received(:get_identifier_events).with(identifier, "west")
        expect(IdentifierService).to have_received(:get_identifier_events).with(identifier, "east")
        expect(IdentifierService).to have_received(:get_identifier_events).with(identifier, "europe")
      end

      it "assigns @events merged and sorted by timestamp" do
        get :identifier, params: { identifier: identifier }

        expect(assigns(:events).size).to eq(2)
        expect(assigns(:events).map { |e| e["timestamp"] }).to eq(%w[2024-01-01T09:00:00 2024-01-02T10:00:00])
      end

      it "does not set @error" do
        get :identifier, params: { identifier: identifier }
        expect(assigns(:error)).to be_nil
      end
    end

    context "when identifier is blank but guid is provided" do
      let(:guid) { "guid-456" }
      let(:events) { [{ "server" => "west", "timestamp" => "2024-01-01T12:00:00", "event" => "ping" }] }

      before do
        allow(IdentifierService).to receive(:get_identifier_events).with(guid, "west").and_return(events)
        allow(IdentifierService).to receive(:get_identifier_events).with(guid, "east").and_return([])
        allow(IdentifierService).to receive(:get_identifier_events).with(guid, "europe").and_return([])
      end

      it "assigns @identifier from params[:guid] and @events from the lookup" do
        get :identifier, params: { identifier: "", guid: guid }
        expect(assigns(:identifier)).to eq(guid)
        expect(assigns(:events)).to eq(events)
      end
    end

    context "when both identifier and guid are blank" do
      before do
        allow(IdentifierService).to receive(:get_identifier_events)
      end

      it "assigns blank @identifier and empty @events, and does not call IdentifierService" do
        get :identifier, params: { identifier: "", guid: "   " }

        expect(assigns(:identifier)).to be_blank
        expect(assigns(:events)).to eq([])
        expect(IdentifierService).not_to have_received(:get_identifier_events)
      end
    end

    context "when identifier has surrounding whitespace" do
      before do
        allow(IdentifierService).to receive(:get_identifier_events).with("trimmed", "west").and_return([])
        allow(IdentifierService).to receive(:get_identifier_events).with("trimmed", "east").and_return([])
        allow(IdentifierService).to receive(:get_identifier_events).with("trimmed", "europe").and_return([])
      end

      it "assigns stripped @identifier" do
        get :identifier, params: { identifier: "  trimmed  " }
        expect(assigns(:identifier)).to eq("trimmed")
      end
    end

    context "when IdentifierService raises" do
      before do
        allow(IdentifierService).to receive(:get_identifier_events).and_raise(StandardError.new("redis down"))
        allow(Rails.logger).to receive(:error)
      end

      it "returns a success response (page still renders)" do
        get :identifier, params: { identifier: "abc" }
        expect(response).to be_successful
      end

      it "assigns @error and sets @events to []" do
        get :identifier, params: { identifier: "abc" }

        expect(assigns(:error)).to eq("Unable to load identifier data.")
        expect(assigns(:events)).to eq([])
      end

      it "logs the error" do
        get :identifier, params: { identifier: "abc" }
        expect(Rails.logger).to have_received(:error).with("[PagesController#identifier] redis down")
      end
    end
  end

  describe "GET #items" do
    context "when AoBinDumpsItemsService returns success" do
      let(:items_list) do
        [
          { "Index" => "1", "UniqueName" => "T1_ORE", "LocalizedNames" => { "EN-US" => "Ore", "DE-DE" => "Erz" } },
          { "Index" => "2", "UniqueName" => "T2_ORE", "LocalizedNames" => { "EN-US" => "Iron Ore" } }
        ]
      end
      let(:language_keys) { %w[DE-DE EN-US] }
      let(:service_result) do
        AoBinDumpsItemsService::Result.new(items: items_list, language_keys: language_keys, error: nil)
      end

      before do
        allow(AoBinDumpsItemsService).to receive(:call).and_return(service_result)
        allow(AoBinDumpsItemsService).to receive(:search).with(items_list, "").and_return(items_list)
      end

      it "returns a success response" do
        get :items
        expect(response).to be_successful
      end

      it "assigns @items_list, @language_keys, @query, @lang, and @results" do
        get :items

        expect(assigns(:items_list)).to eq(items_list)
        expect(assigns(:language_keys)).to eq(language_keys)
        expect(assigns(:query)).to eq("")
        expect(assigns(:lang)).to eq("EN-US")
        expect(assigns(:results)).to eq(items_list)
        expect(assigns(:items_error)).to be_nil
      end

      it "calls AoBinDumpsItemsService.call and then search with items and query" do
        get :items
        expect(AoBinDumpsItemsService).to have_received(:call)
        expect(AoBinDumpsItemsService).to have_received(:search).with(items_list, "")
      end

      it "assigns stripped @query and passes it to search" do
        filtered = [items_list.second]
        allow(AoBinDumpsItemsService).to receive(:search).with(items_list, "iron").and_return(filtered)

        get :items, params: { q: "  iron  " }

        expect(assigns(:query)).to eq("iron")
        expect(assigns(:results)).to eq(filtered)
        expect(AoBinDumpsItemsService).to have_received(:search).with(items_list, "iron")
      end

      it "assigns @lang from params when provided" do
        get :items, params: { lang: "DE-DE" }
        expect(assigns(:lang)).to eq("DE-DE")
      end

      it "assigns first language key as @lang when EN-US is not in language_keys" do
        result_no_en = AoBinDumpsItemsService::Result.new(
          items: items_list,
          language_keys: %w[DE-DE FR-FR],
          error: nil
        )
        allow(AoBinDumpsItemsService).to receive(:call).and_return(result_no_en)
        allow(AoBinDumpsItemsService).to receive(:search).and_return(items_list)

        get :items

        expect(assigns(:lang)).to eq("DE-DE")
      end
    end

    context "when AoBinDumpsItemsService returns an error" do
      let(:failed_result) do
        AoBinDumpsItemsService::Result.new(items: [], language_keys: [], error: "Unable to load items")
      end

      before do
        allow(AoBinDumpsItemsService).to receive(:call).and_return(failed_result)
        allow(AoBinDumpsItemsService).to receive(:search)
      end

      it "returns a success response (page still renders)" do
        get :items
        expect(response).to be_successful
      end

      it "assigns @items_error and empty @items_list and @language_keys" do
        get :items

        expect(assigns(:items_error)).to eq("Unable to load items")
        expect(assigns(:items_list)).to eq([])
        expect(assigns(:language_keys)).to eq([])
      end

      it "does not call AoBinDumpsItemsService.search" do
        get :items
        expect(AoBinDumpsItemsService).not_to have_received(:search)
      end
    end
  end
end
