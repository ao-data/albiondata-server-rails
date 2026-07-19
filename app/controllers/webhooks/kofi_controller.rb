class Webhooks::KofiController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_around_action :run_using_database

  def create
    return head :service_unavailable if ENV['KOFI_VERIFICATION_TOKEN'].blank?

    begin
      payload = JSON.parse(params[:data])
    rescue JSON::ParserError, TypeError
      return head :bad_request
    end

    return head :unauthorized if payload['verification_token'] != ENV['KOFI_VERIFICATION_TOKEN']
    return head :ok if payload['is_public'] == false

    KofiDiscordNotificationWorker.perform_async(payload['amount'], payload['type'])

    head :ok
  end
end
