require 'rails_helper'

RSpec.describe Webhooks::KofiController, :type => :controller do
  describe "POST #create" do
    let(:payload) do
      {
        verification_token: 'correct_token',
        is_public: true,
        amount: '3.00',
        type: 'Donation',
      }
    end

    before do
      @old_token = ENV['KOFI_VERIFICATION_TOKEN']
    end

    after do
      ENV['KOFI_VERIFICATION_TOKEN'] = @old_token
    end

    context "when KOFI_VERIFICATION_TOKEN is unset" do
      before { ENV['KOFI_VERIFICATION_TOKEN'] = nil }

      it "responds 503 and does not enqueue the worker" do
        expect(KofiDiscordNotificationWorker).to_not receive(:perform_async)

        post :create, params: { data: payload.to_json }

        expect(response).to have_http_status(503)
      end
    end

    context "when KOFI_VERIFICATION_TOKEN is blank" do
      before { ENV['KOFI_VERIFICATION_TOKEN'] = '' }

      it "responds 503 and does not enqueue the worker" do
        expect(KofiDiscordNotificationWorker).to_not receive(:perform_async)

        post :create, params: { data: payload.to_json }

        expect(response).to have_http_status(503)
      end
    end

    context "when KOFI_VERIFICATION_TOKEN is configured" do
      before { ENV['KOFI_VERIFICATION_TOKEN'] = 'correct_token' }

      context "and the data param is malformed JSON" do
        it "responds 400 and does not enqueue the worker" do
          expect(KofiDiscordNotificationWorker).to_not receive(:perform_async)

          post :create, params: { data: 'not json' }

          expect(response).to have_http_status(400)
        end
      end

      context "and the verification_token does not match" do
        it "responds 401 and does not enqueue the worker" do
          expect(KofiDiscordNotificationWorker).to_not receive(:perform_async)

          post :create, params: { data: payload.merge(verification_token: 'wrong').to_json }

          expect(response).to have_http_status(401)
        end
      end

      context "and is_public is false" do
        it "responds 200 and does not enqueue the worker" do
          expect(KofiDiscordNotificationWorker).to_not receive(:perform_async)

          post :create, params: { data: payload.merge(is_public: false).to_json }

          expect(response).to have_http_status(200)
        end
      end

      context "and the payload is valid and public" do
        it "responds 200 and enqueues the worker with amount and type" do
          expect(KofiDiscordNotificationWorker).to receive(:perform_async).with('3.00', 'Donation')

          post :create, params: { data: payload.to_json }

          expect(response).to have_http_status(200)
        end
      end
    end
  end
end
