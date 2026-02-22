# frozen_string_literal: true

require "rails_helper"

RSpec.describe AoBinDumpsItemsService, type: :service do
  let(:items_url) { described_class::ITEMS_URL }
  let(:cache_key) { described_class::CACHE_KEY }
  let(:cache_duration) { described_class::CACHE_DURATION }

  describe ".call" do
    it "returns the result from #call on a new instance" do
      result = instance_double(described_class::Result)
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
        allow(Rails.cache).to receive(:fetch).with(cache_key, expires_in: cache_duration).and_yield
      end

      context "when the API response is successful" do
        let(:raw_items) do
          [
            {
              "Index" => "1",
              "UniqueName" => "T1_ORE",
              "LocalizedNames" => { "EN-US" => "Ore", "DE-DE" => "Erz" }
            },
            {
              "Index" => "2",
              "UniqueName" => "T2_ORE",
              "LocalizedNames" => { "EN-US" => "Iron Ore" }
            }
          ]
        end

        let(:response) do
          double("HTTParty::Response", success?: true, body: raw_items.to_json)
        end

        before do
          allow(HTTParty).to receive(:get).with(items_url, headers: { "User-Agent" => "AlbionDataServer" }).and_return(response)
        end

        it "calls the items URL with the correct User-Agent" do
          service.call

          expect(HTTParty).to have_received(:get).with(items_url, headers: { "User-Agent" => "AlbionDataServer" })
        end

        it "returns a Result with normalized items and language_keys" do
          result = service.call

          expect(result).to be_a(described_class::Result)
          expect(result.success?).to be true
          expect(result.error).to be_nil
          expect(result.items.size).to eq(2)
          expect(result.items.first).to eq(
            "Index" => "1",
            "UniqueName" => "T1_ORE",
            "LocalizedNames" => { "EN-US" => "Ore", "DE-DE" => "Erz" }
          )
          expect(result.language_keys).to eq(%w[DE-DE EN-US])
        end
      end

      context "when the API response is not successful" do
        let(:response) { double("HTTParty::Response", success?: false) }

        before do
          allow(HTTParty).to receive(:get).and_return(response)
        end

        it "returns a Result with an error message" do
          result = service.call

          expect(result).to be_a(described_class::Result)
          expect(result.success?).to be false
          expect(result.error).to eq("Unable to load items")
          expect(result.items).to eq([])
        end
      end

      context "when the API raises an exception" do
        before do
          allow(HTTParty).to receive(:get).and_raise(StandardError.new("network error"))
          allow(Rails.logger).to receive(:warn)
        end

        it "returns a Result with an error message" do
          result = service.call

          expect(result.error).to eq("Unable to load items")
        end

        it "logs a warning" do
          service.call

          expect(Rails.logger).to have_received(:warn).with("[AoBinDumpsItemsService] network error")
        end
      end

      context "with edge cases" do
        it "normalizes items: skips entries without UniqueName and Index" do
          raw = [
            { "Index" => "1", "UniqueName" => "KEEP", "LocalizedNames" => {} },
            { "UniqueName" => "", "Index" => "" },
            { "Index" => "2", "UniqueName" => "KEEP2", "LocalizedNames" => nil }
          ]
          response = double(success?: true, body: raw.to_json)
          allow(HTTParty).to receive(:get).and_return(response)

          result = service.call

          expect(result.items.size).to eq(2)
          expect(result.items.map { |i| i["UniqueName"] }).to eq(%w[KEEP KEEP2])
        end

        it "handles non-Hash entries and non-Array raw" do
          raw = [
            { "Index" => "1", "UniqueName" => "A", "LocalizedNames" => {} },
            "not a hash",
            nil
          ]
          response = double(success?: true, body: raw.to_json)
          allow(HTTParty).to receive(:get).and_return(response)

          result = service.call

          expect(result.items.size).to eq(1)
          expect(result.items.first["UniqueName"]).to eq("A")
        end

        it "treats non-Hash LocalizedNames as empty" do
          raw = [
            { "Index" => "1", "UniqueName" => "X", "LocalizedNames" => "invalid" }
          ]
          response = double(success?: true, body: raw.to_json)
          allow(HTTParty).to receive(:get).and_return(response)

          result = service.call

          expect(result.items.first["LocalizedNames"]).to eq({})
          expect(result.language_keys).to eq([])
        end

        it "includes entries with only Index (no UniqueName)" do
          raw = [
            { "Index" => "99", "UniqueName" => nil, "LocalizedNames" => {} }
          ]
          response = double(success?: true, body: raw.to_json)
          allow(HTTParty).to receive(:get).and_return(response)

          result = service.call

          expect(result.items.size).to eq(1)
          expect(result.items.first["Index"]).to eq("99")
        end
      end
    end

    context "when cache returns an error hash" do
      before do
        allow(Rails.cache).to receive(:fetch).with(cache_key, expires_in: cache_duration).and_return({ error: "Unable to load items" })
        allow(HTTParty).to receive(:get)
      end

      it "returns a Result with the error and does not call the API" do
        result = service.call

        expect(result.success?).to be false
        expect(result.error).to eq("Unable to load items")
        expect(HTTParty).not_to have_received(:get)
      end
    end

    context "when cache is populated with valid data" do
      let(:cached_raw) do
        [
          { "Index" => "1", "UniqueName" => "CACHED", "LocalizedNames" => { "EN-US" => "Cached Item" } }
        ]
      end

      before do
        allow(Rails.cache).to receive(:fetch).with(cache_key, expires_in: cache_duration).and_return(cached_raw)
        allow(HTTParty).to receive(:get)
      end

      it "returns normalized items from cache without calling the API" do
        result = service.call

        expect(result.success?).to be true
        expect(result.items.size).to eq(1)
        expect(result.items.first["UniqueName"]).to eq("CACHED")
        expect(result.language_keys).to eq(%w[EN-US])
        expect(HTTParty).not_to have_received(:get)
      end
    end
  end

  describe ".search" do
    it "delegates to #search on a new instance" do
      items = []
      service = instance_double(described_class, search: items)
      allow(described_class).to receive(:new).and_return(service)

      expect(described_class.search(items, "ore")).to eq(items)
      expect(service).to have_received(:search).with(items, "ore")
    end
  end

  describe "#search" do
    let(:service) { described_class.new }
    let(:items) do
      [
        { "Index" => "1", "UniqueName" => "T1_ORE", "LocalizedNames" => { "EN-US" => "Ore" } },
        { "Index" => "2", "UniqueName" => "T2_ORE", "LocalizedNames" => { "EN-US" => "Iron Ore" } },
        { "Index" => "3", "UniqueName" => "T3_FISH", "LocalizedNames" => { "EN-US" => "Spotted Trout" } },
        { "Index" => "4", "UniqueName" => "T4_ORE", "LocalizedNames" => { "EN-US" => "Copper Ore" } }
      ]
    end

    it "returns all items when query is blank" do
      expect(service.search(items, nil)).to eq(items)
      expect(service.search(items, "")).to eq(items)
      expect(service.search(items, "   ")).to eq(items)
    end

    it "matches by UniqueName (case-insensitive)" do
      result = service.search(items, "T2_ORE")

      expect(result.size).to eq(1)
      expect(result.first["UniqueName"]).to eq("T2_ORE")
    end

    it "matches by Index" do
      result = service.search(items, "3")

      expect(result.size).to eq(1)
      expect(result.first["Index"]).to eq("3")
    end

    it "matches by localized name (word boundary): 'ore' matches 'Ore', 'Iron Ore', 'Copper Ore'" do
      result = service.search(items, "ore")

      expect(result.map { |i| i["UniqueName"] }).to match_array(%w[T1_ORE T2_ORE T4_ORE])
      expect(result.map { |i| i["UniqueName"] }).not_to include("T3_FISH")
    end

    it "does not match substring within word: 'ore' does not match 'Spotted Trout'" do
      result = service.search(items, "ore")

      trout = result.find { |i| i["UniqueName"] == "T3_FISH" }
      expect(trout).to be_nil
    end

    it "strips and downcases the query" do
      result = service.search(items, "  IRON ORE  ")

      expect(result.size).to eq(1)
      expect(result.first["UniqueName"]).to eq("T2_ORE")
    end

    it "returns empty array when no items match" do
      result = service.search(items, "nonexistent")

      expect(result).to eq([])
    end
  end

  describe AoBinDumpsItemsService::Result do
    describe "#success?" do
      it "returns true when error is nil" do
        result = AoBinDumpsItemsService::Result.new(items: [], language_keys: [])

        expect(result.success?).to be true
      end

      it "returns false when error is present" do
        result = AoBinDumpsItemsService::Result.new(items: [], error: "Something went wrong")

        expect(result.success?).to be false
      end
    end

    it "exposes items, error, and language_keys" do
      result = AoBinDumpsItemsService::Result.new(
        items: [{ "UniqueName" => "X" }],
        error: nil,
        language_keys: %w[EN-US]
      )

      expect(result.items).to eq([{ "UniqueName" => "X" }])
      expect(result.error).to be_nil
      expect(result.language_keys).to eq(%w[EN-US])
    end
  end
end
