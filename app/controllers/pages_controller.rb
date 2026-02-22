# frozen_string_literal: true

class PagesController < ApplicationController
  skip_around_action :run_using_database, only: [:index, :faq, :api, :client, :developer, :identifier, :items, :third_party_tools]

  def index
    @unique_agents_stats = UniqueAgentsStatsService.call
  end

  def faq
  end

  def api
  end

  def third_party_tools
  end

  def developer
  end

  def client
    @client_download_stats = GithubReleaseStatsService.call
  end

  def identifier
    @identifier = params[:identifier].to_s.strip.presence || params[:guid].to_s.strip.presence
    if @identifier.blank?
      @events = []
      return
    end

    servers = %w[west east europe]
    @events = servers.flat_map { |server| IdentifierService.get_identifier_events(@identifier, server) }
                     .sort_by { |ev| ev["timestamp"].to_s }
  rescue StandardError => e
    Rails.logger.error("[PagesController#identifier] #{e.message}")
    @error = "Unable to load identifier data."
    @events = []
  end

  def items
    result = AoBinDumpsItemsService.call
    unless result.success?
      @items_error = result.error
      @items_list = []
      @language_keys = []
      return
    end

    @language_keys = result.language_keys
    @items_list = result.items
    @query = params[:q].to_s.strip
    default_lang = @language_keys.include?("EN-US") ? "EN-US" : @language_keys.first
    @lang = params[:lang].to_s.strip.presence || default_lang
    @results = AoBinDumpsItemsService.search(@items_list, @query)
  end
end
