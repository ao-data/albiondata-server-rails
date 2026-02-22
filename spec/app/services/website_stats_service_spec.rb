# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebsiteStatsService, type: :service do
  # Build a fake InfluxDB table for UniqueAgents (server_id, _time, _value).
  def unique_agents_table(server_id:, time:, value:)
    rec = double("record", values: { "server_id" => server_id, "_time" => time, "_value" => value })
    double("table", records: [rec]).tap { |t| allow(t).to receive(:records).and_return([rec]) }
  end

  # Build a fake InfluxDB table for DuplicateItems (server_id, _field, _time, _value).
  def duplicate_items_table(server_id:, field:, time:, value:)
    rec = double("record", values: { "server_id" => server_id, "_field" => field, "_time" => time, "_value" => value })
    double("table", records: [rec]).tap { |t| allow(t).to receive(:records).and_return([rec]) }
  end

  describe WebsiteStatsService::UniqueAgents do
    let(:cache_key) { described_class::CACHE_KEY }
    let(:refresh_lock_key) { described_class::REFRESH_LOCK_KEY }

    describe ".call" do
      context "when cache is empty" do
        before do
          allow(Rails.cache).to receive(:read).with(cache_key).and_return(nil)
          allow(Rails.cache).to receive(:read).with(refresh_lock_key).and_return(nil)
          allow(Rails.cache).to receive(:write)
          allow(Rails.cache).to receive(:delete)
          allow(Thread).to receive(:new).and_yield
          allow(described_class).to receive(:fetch_data).and_return(nil)
        end

        it "returns nil" do
          expect(described_class.call).to be_nil
        end

        it "spawns a background refresh" do
          expect(Thread).to receive(:new).and_yield

          described_class.call

          expect(Rails.cache).to have_received(:write).with(refresh_lock_key, true, expires_in: described_class::REFRESH_LOCK_EXPIRY)
        end
      end

      context "when cache is fresh (age < 5 min)" do
        let(:cached_data) { { labels: ["2025-01-01T12:00:00.000Z"], datasets: [] } }
        let(:entry) { { data: cached_data, cached_at: Time.now.to_f } }

        before do
          allow(Rails.cache).to receive(:read).with(cache_key).and_return(entry)
        end

        it "returns cached data" do
          expect(described_class.call).to eq(cached_data)
        end

        it "does not call spawn_refresh_if_needed" do
          expect(described_class).not_to receive(:spawn_refresh_if_needed)

          described_class.call
        end
      end

      context "when cache is stale (age >= 5 min)" do
        let(:cached_data) { { labels: ["2025-01-01T12:00:00.000Z"], datasets: [] } }
        let(:entry) { { data: cached_data, cached_at: Time.now.to_f - 6 * 60 } }

        before do
          allow(Rails.cache).to receive(:read).with(cache_key).and_return(entry)
          allow(Rails.cache).to receive(:read).with(refresh_lock_key).and_return(nil)
          allow(Rails.cache).to receive(:write)
          allow(Rails.cache).to receive(:delete)
          allow(Thread).to receive(:new).and_yield
          allow(described_class).to receive(:fetch_data).and_return(nil)
        end

        it "returns cached data" do
          expect(described_class.call).to eq(cached_data)
        end

        it "spawns a background refresh" do
          expect(Thread).to receive(:new).and_yield

          described_class.call

          expect(Rails.cache).to have_received(:write).with(refresh_lock_key, true, expires_in: described_class::REFRESH_LOCK_EXPIRY)
        end
      end
    end

    describe ".spawn_refresh_if_needed" do
      context "when refresh lock is already set" do
        before do
          allow(Rails.cache).to receive(:read).with(refresh_lock_key).and_return(true)
        end

        it "does not write the lock or spawn a thread" do
          expect(Rails.cache).not_to receive(:write)
          expect(Thread).not_to receive(:new)

          described_class.send(:spawn_refresh_if_needed)
        end
      end

      context "when refresh lock is not set" do
        before do
          allow(Rails.cache).to receive(:read).with(refresh_lock_key).and_return(nil)
          allow(Rails.cache).to receive(:write)
          allow(Rails.cache).to receive(:delete)
          allow(Thread).to receive(:new).and_yield
        end

        it "writes the lock and spawns a thread" do
          allow(described_class).to receive(:fetch_data).and_return(nil)

          described_class.send(:spawn_refresh_if_needed)

          expect(Rails.cache).to have_received(:write).with(refresh_lock_key, true, expires_in: described_class::REFRESH_LOCK_EXPIRY)
          expect(Thread).to have_received(:new)
        end

        it "when fetch_data returns result, writes cache and deletes lock" do
          result = { labels: ["t1"], datasets: [] }
          allow(described_class).to receive(:fetch_data).and_return(result)

          described_class.send(:spawn_refresh_if_needed)

          expect(Rails.cache).to have_received(:write).with(
            cache_key,
            hash_including(data: result, cached_at: kind_of(Numeric)),
            expires_in: described_class::CACHE_EXPIRY
          )
          expect(Rails.cache).to have_received(:delete).with(refresh_lock_key)
        end

        it "when fetch_data raises, logs and deletes lock" do
          allow(described_class).to receive(:fetch_data).and_raise(StandardError.new("influx error"))
          allow(Rails.logger).to receive(:warn)

          described_class.send(:spawn_refresh_if_needed)

          expect(Rails.logger).to have_received(:warn).with(/background refresh failed: influx error/)
          expect(Rails.cache).to have_received(:delete).with(refresh_lock_key)
        end
      end
    end

    describe ".fetch_data" do
      context "when InfluxDB env vars are missing" do
        before do
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with("INFLUXDB_URL").and_return(nil)
          allow(ENV).to receive(:[]).with("INFLUXDB_TOKEN").and_return(nil)
        end

        it "returns nil" do
          expect(described_class.send(:fetch_data)).to be_nil
        end
      end

      context "when InfluxDB client raises" do
        before do
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with("INFLUXDB_URL").and_return("http://localhost:8086")
          allow(ENV).to receive(:[]).with("INFLUXDB_TOKEN").and_return("token")
          allow(ENV).to receive(:[]).with("INFLUXDB_BUCKET").and_return("AODP")
          allow(ENV).to receive(:[]).with("INFLUXDB_ORG").and_return("org")
          client = double("client")
          query_api = double("query_api")
          allow(ActiveSupportNotificationService).to receive(:client).and_return(client)
          allow(client).to receive(:create_query_api).and_return(query_api)
          allow(query_api).to receive(:query).and_raise(StandardError.new("connection refused"))
          allow(Rails.logger).to receive(:warn)
        end

        it "returns nil and logs" do
          expect(described_class.send(:fetch_data)).to be_nil
          expect(Rails.logger).to have_received(:warn).with(/WebsiteStatsService::UniqueAgents/)
        end
      end
    end

    describe ".build_chart_data" do
      it "returns nil when tables are empty" do
        table = double("table", records: [])
        result = described_class.send(:build_chart_data, [table])

        expect(result).to be_nil
      end

      it "builds labels and datasets from table records" do
        time_str = "2025-01-01T12:00:00.000Z"
        tables = [
          unique_agents_table(server_id: "east", time: time_str, value: 10),
          unique_agents_table(server_id: "west", time: time_str, value: 5)
        ]

        result = described_class.send(:build_chart_data, tables)

        expect(result).to be_a(Hash)
        expect(result[:labels]).to eq([time_str])
        expect(result[:datasets].size).to eq(2)
        expect(result[:datasets].map { |d| d[:label] }).to contain_exactly("Asia", "Americas")
        expect(result[:datasets].find { |d| d[:server_id] == "east" }[:data]).to eq([10])
        expect(result[:datasets].find { |d| d[:server_id] == "west" }[:data]).to eq([5])
      end

      it "skips records with nil time or value" do
        rec1 = double("record", values: { "server_id" => "east", "_time" => "2025-01-01T12:00:00Z", "_value" => 1 })
        rec2 = double("record", values: { "server_id" => "east", "_time" => nil, "_value" => 2 })
        table = double("table", records: [rec1, rec2])

        result = described_class.send(:build_chart_data, [table])

        expect(result).not_to be_nil
        expect(result[:datasets].first[:data]).to eq([1])
      end
    end
  end

  describe WebsiteStatsService::DuplicateItems do
    let(:cache_key) { described_class::CACHE_KEY }
    let(:refresh_lock_key) { described_class::REFRESH_LOCK_KEY }

    describe ".call" do
      context "when cache is empty" do
        before do
          allow(Rails.cache).to receive(:read).with(cache_key).and_return(nil)
          allow(Rails.cache).to receive(:read).with(refresh_lock_key).and_return(nil)
          allow(Rails.cache).to receive(:write)
          allow(Rails.cache).to receive(:delete)
          allow(Thread).to receive(:new).and_yield
          allow(described_class).to receive(:fetch_data).and_return(nil)
        end

        it "returns nil" do
          expect(described_class.call).to be_nil
        end

        it "spawns a background refresh" do
          expect(Thread).to receive(:new).and_yield

          described_class.call

          expect(Rails.cache).to have_received(:write).with(refresh_lock_key, true, expires_in: described_class::REFRESH_LOCK_EXPIRY)
        end
      end

      context "when cache has data" do
        let(:cached_data) { { labels: ["2025-01-01T12:00:00.000Z"], datasets: [] } }
        let(:entry) { { data: cached_data, cached_at: Time.now.to_f } }

        before do
          allow(Rails.cache).to receive(:read).with(cache_key).and_return(entry)
        end

        it "returns cached data" do
          expect(described_class.call).to eq(cached_data)
        end
      end
    end

    describe ".spawn_refresh_if_needed" do
      context "when refresh lock is already set" do
        before { allow(Rails.cache).to receive(:read).with(refresh_lock_key).and_return(true) }

        it "does not spawn a thread" do
          expect(Thread).not_to receive(:new)
          described_class.send(:spawn_refresh_if_needed)
        end
      end
    end

    describe ".fetch_data" do
      context "when InfluxDB env vars are missing" do
        before do
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with("INFLUXDB_URL").and_return("")
          allow(ENV).to receive(:[]).with("INFLUXDB_TOKEN").and_return("")
        end

        it "returns nil" do
          expect(described_class.send(:fetch_data)).to be_nil
        end
      end

      context "when InfluxDB client raises" do
        before do
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with("INFLUXDB_URL").and_return("http://localhost:8086")
          allow(ENV).to receive(:[]).with("INFLUXDB_TOKEN").and_return("token")
          allow(ENV).to receive(:[]).with("INFLUXDB_BUCKET").and_return("AODP")
          allow(ENV).to receive(:[]).with("INFLUXDB_ORG").and_return("org")
          client = double("client")
          query_api = double("query_api")
          allow(ActiveSupportNotificationService).to receive(:client).and_return(client)
          allow(client).to receive(:create_query_api).and_return(query_api)
          allow(query_api).to receive(:query).and_raise(StandardError.new("timeout"))
          allow(Rails.logger).to receive(:warn)
        end

        it "returns nil and logs" do
          expect(described_class.send(:fetch_data)).to be_nil
          expect(Rails.logger).to have_received(:warn).with(/WebsiteStatsService::DuplicateItems/)
        end
      end
    end

    describe ".build_chart_data" do
      it "returns nil when tables are empty" do
        table = double("table", records: [])
        result = described_class.send(:build_chart_data, [table])

        expect(result).to be_nil
      end

      it "builds labels and datasets with server and field labels" do
        time_str = "2025-01-01T12:00:00.000Z"
        tables = [
          duplicate_items_table(server_id: "east", field: "duplicates", time: time_str, value: 100),
          duplicate_items_table(server_id: "east", field: "non_duplicates", time: time_str, value: 200)
        ]

        result = described_class.send(:build_chart_data, tables)

        expect(result).to be_a(Hash)
        expect(result[:labels]).to eq([time_str])
        expect(result[:datasets].size).to eq(2)
        expect(result[:datasets].map { |d| d[:label] }).to contain_exactly("Asia - Duplicates", "Asia - Non-duplicates")
        expect(result[:datasets].find { |d| d[:field] == "duplicates" }[:data]).to eq([100])
        expect(result[:datasets].find { |d| d[:field] == "non_duplicates" }[:data]).to eq([200])
      end
    end
  end
end
