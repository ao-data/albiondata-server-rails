# == Route Map
#

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  namespace :api, defaults: {format: 'json'} do
    namespace :v2 do
      match "stats/prices/:id", controller: "stats", action: "show_json", via: :get
      match "stats/view/:id", controller: "stats", action: "show_table", via: :get

      resources :stats
    end
  end


end
