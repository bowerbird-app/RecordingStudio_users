Rails.application.routes.draw do
  # RecordingStudioUser routes
  devise_for :users,
             class_name: RecordingStudioUser.configuration.user_model,
             controllers: {
               sessions: "recording_studio_user/devise/sessions",
               passwords: "recording_studio_user/devise/passwords"
             }
  resource :profile,
           path: RecordingStudioUser.configuration.profile_path,
           only: %i[show edit update],
           controller: "recording_studio_user/profiles"

  # RecordingStudio engine is data/API-focused and has no browser root route.
  # Keep legacy links working by redirecting the base path to the app home.
  get "/recording_studio", to: redirect("/"), as: nil
  mount RecordingStudio::Engine, at: "/recording_studio"
  recording_studio_admin_for :admin, at: "/admin", root_section: :root

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
