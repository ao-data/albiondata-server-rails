# == Route Map
#

require 'sidekiq/web'

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  mount Sidekiq::Web => '/sidekiq'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  namespace :api, defaults: {format: 'json'} do
    namespace :v2 do
      namespace :stats do
        match "prices/:id", controller: "prices", action: "show", via: :get
        match "view/:id", controller: "prices", action: "show_table", via: :get

        match "gold", controller: "gold", action: "index", via: :get
      end

      # resources :stats
    end
  end


end
