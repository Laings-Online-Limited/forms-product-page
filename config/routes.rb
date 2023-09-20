Rails.application.routes.draw do
  get :ping, controller: :heartbeat

  # Defines the root path route ("/")
  root "pages#index"

  get "/features" => "pages#features"
  get "/accessibility" => "pages#accessibility"
  get "/cookies" => "pages#cookies"
  get "/privacy" => "pages#privacy"

  get "/support" => "support#support"

  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_server_error", via: :all
end
