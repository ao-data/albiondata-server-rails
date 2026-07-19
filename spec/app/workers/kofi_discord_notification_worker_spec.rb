require 'rails_helper'

RSpec.describe KofiDiscordNotificationWorker, :type => :worker do
  describe '#perform' do
    before do
      @old_webhook_url = ENV['DISCORD_DONATE_WEBHOOK_URL']
    end

    after do
      ENV['DISCORD_DONATE_WEBHOOK_URL'] = @old_webhook_url
    end

    context 'when DISCORD_DONATE_WEBHOOK_URL is present' do
      before do
        ENV['DISCORD_DONATE_WEBHOOK_URL'] = 'webhook_url'
      end

      it 'posts a one-time tip message to discord' do
        expect(HTTParty).to receive(:post).with('webhook_url', body: { content: "☕ New one-time tip: $3.00 on Ko-fi!" }.to_json, headers: { 'Content-Type' => 'application/json' })
        subject.perform('3.00', 'Donation')
      end

      it 'posts a subscription message to discord' do
        expect(HTTParty).to receive(:post).with('webhook_url', body: { content: "🎉 New subscription tip: $5.00 on Ko-fi!" }.to_json, headers: { 'Content-Type' => 'application/json' })
        subject.perform('5.00', 'Subscription')
      end
    end

    context 'when DISCORD_DONATE_WEBHOOK_URL is blank' do
      before do
        ENV['DISCORD_DONATE_WEBHOOK_URL'] = ''
      end

      it 'does not post to discord' do
        expect(HTTParty).to_not receive(:post)
        subject.perform('3.00', 'Donation')
      end
    end

    context 'when DISCORD_DONATE_WEBHOOK_URL is unset' do
      before do
        ENV['DISCORD_DONATE_WEBHOOK_URL'] = nil
      end

      it 'does not post to discord' do
        expect(HTTParty).to_not receive(:post)
        subject.perform('3.00', 'Donation')
      end
    end
  end
end
