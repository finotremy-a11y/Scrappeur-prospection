Rails.application.routes.draw do
  root "organizations#index"
  resources :organizations, only: [:index, :destroy]
  
  # Campaign management
  get  "campaigns",         to: "campaigns#index",        as: :campaigns
  post "campaigns/send",    to: "campaigns#send_campaign", as: :send_campaign
  get  "campaigns/preview", to: "campaigns#preview",       as: :preview_campaign

  # RGPD unsubscribe link
  get "unsubscribe/:id", to: "campaigns#unsubscribe", as: :unsubscribe
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
