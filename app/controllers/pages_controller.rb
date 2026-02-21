# frozen_string_literal: true

class PagesController < ApplicationController
  skip_around_action :run_using_database, only: [:index, :faq, :api, :client, :identifier]

  def index
  end

  def faq
  end

  def api
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
end
