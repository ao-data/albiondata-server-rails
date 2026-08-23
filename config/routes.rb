# == Route Map
#

require 'sidekiq/web'
require 'sidekiq/cron/web'

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  mount Sidekiq::Web => '/sidekiq'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "pages#index"
  get "client", to: "pages#client", as: :client
  get "client-faq", to: "pages#faq", as: :client_faq
  get "api", to: "pages#api", as: :api_info
  get "3rd-party-tools", to: "pages#third_party_tools", as: :third_party_tools
  get "developer", to: "pages#developer", as: :developer
  get "donate", to: "pages#donate", as: :donate
  get "identifier", to: "pages#identifier", as: :identifier
  get "items", to: "pages#items", as: :items

  if Rails.env.development? || Rails.env.test?
    match "/test", controller: "application", action: "test", via: :get, :defaults => { :format => 'json' }
  end

  match "/pow", controller: "pow", action: "index", via: :get, :defaults => { :format => 'json' }
  match "/pow/:topic", controller: "pow", action: "reply", via: :post, constraints: { topic: /.*/ }, :defaults => { :format => 'json' }

  namespace :webhooks, defaults: { format: 'json' } do
    post 'kofi', to: 'kofi#create'
  end

  mount StatsAPI => '/'
end
