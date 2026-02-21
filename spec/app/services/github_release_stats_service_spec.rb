# frozen_string_literal: true

require "rails_helper"

RSpec.describe GithubReleaseStatsService, type: :service do
  let(:api_url) { "https://api.github.com/repos/ao-data/albiondata-client/releases" }
  let(:cache_key) { "github_release_stats/ao-data/albiondata-client" }

  describe ".call" do
    it "returns the result from #call on a new instance" do
      result = instance_double(GithubReleaseStatsService::Result)
      service = instance_double(described_class, call: result)
      allow(described_class).to receive(:new).and_return(service)

      expect(described_class.call).to eq(result)
      expect(service).to have_received(:call)
    end
  end

  describe "#call" do
    let(:service) { described_class.new }

    context "when cache is empty" do
      before do
        allow(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 1.hour).and_yield
      end

      context "when the API response is successful" do
        let(:releases) do
          [
            {
              "tag_name" => "v1.2.0",
              "assets" => [
                { "name" => "albiondata-client-windows.zip", "download_count" => 100 },
                { "name" => "albiondata-client-darwin.zip", "download_count" => 50 },
                { "name" => "update-windows.exe", "download_count" => 30 }
              ]
            },
            {
              "tag_name" => "v1.1.0",
              "assets" => [
                { "name" => "albiondata-client-linux.zip", "download_count" => 20 }
              ]
            }
          ]
        end

        let(:response) do
          double("HTTParty::Response", success?: true, parsed_response: releases)
        end

        before do
          allow(HTTParty).to receive(:get).with(api_url, headers: { "User-Agent" => "AlbionDataServer" }).and_return(response)
        end

        it "calls the GitHub API with the correct URL and User-Agent" do
          service.call

          expect(HTTParty).to have_received(:get).with(api_url, headers: { "User-Agent" => "AlbionDataServer" })
        end

        it "returns a Result with aggregated download stats" do
          result = service.call

          expect(result).to be_a(GithubReleaseStatsService::Result)
          expect(result.error).to be_nil
          expect(result.total_downloads).to eq(200) # 100 + 50 + 30 + 20
          expect(result.latest_release_tag).to eq("v1.2.0")
          expect(result.latest_release_downloads).to eq(180) # 100 + 50 + 30
        end

        it "aggregates downloads by OS across all releases" do
          result = service.call

          expect(result.downloads_by_os).to eq("Windows" => 130, "macOS" => 50, "Linux" => 20)
        end

        it "aggregates latest release downloads by OS" do
          result = service.call

          expect(result.latest_downloads_by_os).to eq("Windows" => 130, "macOS" => 50)
        end

        it "aggregates by type (Full install vs Update)" do
          result = service.call

          expect(result.downloads_by_type).to include("Full install" => 170, "Update" => 30)
          expect(result.latest_downloads_by_type).to include("Full install" => 150, "Update" => 30)
        end
      end

      context "when the API response is not successful" do
        let(:response) { double("HTTParty::Response", success?: false) }

        before do
          allow(HTTParty).to receive(:get).and_return(response)
        end

        it "returns a Result with an error message" do
          result = service.call

          expect(result).to be_a(GithubReleaseStatsService::Result)
          expect(result.error).to eq("Unable to load stats")
          expect(result.total_downloads).to be_nil
        end
      end

      context "when the API raises an exception" do
        before do
          allow(HTTParty).to receive(:get).and_raise(StandardError.new("network error"))
          allow(Rails.logger).to receive(:warn)
        end

        it "returns a Result with an error message" do
          result = service.call

          expect(result.error).to eq("Unable to load stats")
        end

        it "logs a warning" do
          service.call

          expect(Rails.logger).to have_received(:warn).with("[GithubReleaseStatsService] network error")
        end
      end

      context "with edge cases" do
        it "skips assets with zero download_count" do
          releases = [
            {
              "tag_name" => "v1.0.0",
              "assets" => [
                { "name" => "client-windows.zip", "download_count" => 10 },
                { "name" => "client-macos.zip", "download_count" => 0 }
              ]
            }
          ]
          response = double(success?: true, parsed_response: releases)
          allow(HTTParty).to receive(:get).and_return(response)

          result = service.call

          expect(result.total_downloads).to eq(10)
          expect(result.downloads_by_os).to eq("Windows" => 10)
        end

        it "handles empty releases array" do
          response = double(success?: true, parsed_response: [])
          allow(HTTParty).to receive(:get).and_return(response)

          result = service.call

          expect(result.total_downloads).to eq(0)
          expect(result.latest_release_tag).to be_nil
          expect(result.latest_release_downloads).to eq(0)
          expect(result.error).to be_nil
        end

        it "classifies unknown asset names as Other OS" do
          releases = [
            {
              "tag_name" => "v1.0.0",
              "assets" => [{ "name" => "something-unknown.xyz", "download_count" => 5 }]
            }
          ]
          response = double(success?: true, parsed_response: releases)
          allow(HTTParty).to receive(:get).and_return(response)

          result = service.call

          expect(result.downloads_by_os).to eq("Other" => 5)
        end
      end
    end

    context "when cache is populated" do
      let(:cached_result) do
        GithubReleaseStatsService::Result.new(
          total_downloads: 999,
          latest_release_tag: "cached",
          latest_release_downloads: 100,
          latest_downloads_by_os: {},
          latest_downloads_by_type: {},
          downloads_by_os: {},
          downloads_by_type: {},
          error: nil
        )
      end

      before do
        allow(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 1.hour).and_return(cached_result)
        allow(HTTParty).to receive(:get)
      end

      it "returns the cached result without calling the API" do
        result = service.call

        expect(result).to eq(cached_result)
        expect(result.total_downloads).to eq(999)
        expect(HTTParty).not_to have_received(:get)
      end
    end
  end
end
