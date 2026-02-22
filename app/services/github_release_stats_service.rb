# frozen_string_literal: true

class GithubReleaseStatsService
  REPO = "ao-data/albiondata-client"
  API_URL = "https://api.github.com/repos/#{REPO}/releases"
  CACHE_KEY = "github_release_stats/#{REPO}"
  CACHE_DURATION = 1.hour

  Result = Struct.new(
    :total_downloads,
    :latest_release_tag,
    :latest_release_downloads,
    :latest_downloads_by_os,
    :latest_downloads_by_type,
    :downloads_by_os,
    :downloads_by_type,
    :error,
    keyword_init: true
  )

  def self.call
    new.call
  end

  def call
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_DURATION) do
      fetch_stats
    end
  end

  private

  def fetch_stats
    response = HTTParty.get(API_URL, headers: { "User-Agent" => "AlbionDataServer" })
    return Result.new(error: "Unable to load stats") unless response.success?

    releases = Array(response.parsed_response)
    by_os = Hash.new(0)
    by_type = Hash.new(0)

    releases.each do |release|
      (release["assets"] || []).each do |asset|
        name = (asset["name"] || "").downcase
        count = asset["download_count"].to_i
        next if count.zero?

        by_os[os_from_name(name)] += count
        by_type[type_from_name(name)] += count
      end
    end

    total = by_os.values.sum
    latest = releases.first
    latest_tag = latest&.dig("tag_name")
    latest_assets = latest ? (latest["assets"] || []) : []
    latest_downloads = latest_assets.sum { |a| a["download_count"].to_i }
    latest_by_os = Hash.new(0)
    latest_by_type = Hash.new(0)
    latest_assets.each do |asset|
      name = (asset["name"] || "").downcase
      count = asset["download_count"].to_i
      next if count.zero?

      latest_by_os[os_from_name(name)] += count
      latest_by_type[type_from_name(name)] += count
    end

    Result.new(
      total_downloads: total,
      latest_release_tag: latest_tag,
      latest_release_downloads: latest_downloads,
      latest_downloads_by_os: latest_by_os,
      latest_downloads_by_type: latest_by_type,
      downloads_by_os: by_os,
      downloads_by_type: by_type,
      error: nil
    )
  rescue StandardError => e
    Rails.logger.warn("[GithubReleaseStatsService] #{e.message}")
    Result.new(error: "Unable to load stats")
  end

  def os_from_name(name)
    return "Windows" if name.include?("windows") || name.include?("installer.exe") || name.include?("update-windows")
    return "macOS" if name.include?("darwin") || name.include?("-mac.") || name.include?("macos")
    return "Linux" if name.include?("linux")

    "Other"
  end

  def type_from_name(name)
    name.start_with?("update-") || name.include?("update-") ? "Update" : "Full install"
  end
end
