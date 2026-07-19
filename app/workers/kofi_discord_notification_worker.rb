class KofiDiscordNotificationWorker
  include Sidekiq::Worker

  MESSAGES = {
    'Donation' => '☕ New one-time tip: $%s on Ko-fi!',
    'Subscription' => '🎉 New subscription tip: $%s on Ko-fi!',
    'SubscriptionPayment' => '🎉 New subscription tip: $%s on Ko-fi!',
  }.freeze

  def perform(amount, type)
    url = ENV['DISCORD_DONATE_WEBHOOK_URL']
    return if url.blank?

    message = format(MESSAGES.fetch(type, MESSAGES['Donation']), amount)
    HTTParty.post(url, body: { content: message }.to_json, headers: { 'Content-Type' => 'application/json' })
  end
end
