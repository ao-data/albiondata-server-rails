# frozen_string_literal: true

class AoBinDumpsItemsService
  ITEMS_URL = "https://raw.githubusercontent.com/ao-data/ao-bin-dumps/master/formatted/items.json"
  CACHE_KEY = "ao_bin_dumps/items.json"
  CACHE_DURATION = 1.hour

  class Result
    attr_reader :items, :error, :language_keys

    def initialize(items: [], error: nil, language_keys: [])
      @items = items
      @error = error
      @language_keys = language_keys
    end

    def success?
      error.nil?
    end
  end

  def self.call
    new.call
  end

  def call
    raw = Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_DURATION) do
      fetch_items
    end
    return Result.new(error: raw[:error]) if raw.is_a?(Hash) && raw[:error]

    items = normalize_items(raw)
    language_keys = collect_language_keys(items)
    Result.new(items: items, language_keys: language_keys)
  end

  def self.search(items, query)
    new.search(items, query)
  end

  def search(items, query)
    return items if query.blank?

    q = query.to_s.strip.downcase
    return items if q.blank?

    items.select do |item|
      match_item?(item, q)
    end
  end

  private

  def fetch_items
    response = HTTParty.get(ITEMS_URL, headers: { "User-Agent" => "AlbionDataServer" })
    return { error: "Unable to load items" } unless response.success?

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.warn("[AoBinDumpsItemsService] #{e.message}")
    { error: "Unable to load items" }
  end

  def normalize_items(raw)
    return [] unless raw.is_a?(Array)

    raw.filter_map do |entry|
      next unless entry.is_a?(Hash)
      next if entry["UniqueName"].to_s.blank? && entry["Index"].to_s.blank?

      {
        "Index" => entry["Index"]&.to_s,
        "UniqueName" => entry["UniqueName"]&.to_s,
        "LocalizedNames" => entry["LocalizedNames"].is_a?(Hash) ? entry["LocalizedNames"] : {}
      }
    end
  end

  def collect_language_keys(items)
    keys = Set.new
    items.each do |item|
      (item["LocalizedNames"] || {}).each_key { |k| keys.add(k) }
    end
    keys.to_a.sort
  end

  def match_item?(item, q)
    return true if item["UniqueName"].to_s.downcase.include?(q)
    return true if item["Index"].to_s.downcase.include?(q)

    # Match display names by whole word so "ore" matches "Ore" / "Iron Ore" but not "Spotted Trout" (or "more", "restore")
    word_re = /\b#{Regexp.escape(q)}\b/i
    (item["LocalizedNames"] || {}).each_value do |name|
      return true if name.to_s.match?(word_re)
    end
    false
  end
end
