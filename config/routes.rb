# frozen_string_literal: true

RecordingStudioUser::Engine.routes.draw do
  resources :otp_codes, only: :show

  resource :profile, only: %i[show edit update], path: RecordingStudioUser.config.profile_route_path do
    get "sign-in-methods", to: "sign_in_methods#show", as: :sign_in_methods
    resources :identities, only: %i[destroy], param: :provider
  end
  get RecordingStudioUser.config.admin_route_path, to: "admin/users#index", as: :admin

  scope module: :auth, path: "auth" do
    get "sign_up", to: "registrations#new", as: :sign_up
    post "sign_up", to: "registrations#continue"
    get "sign_up/password", to: "registrations#password", as: :sign_up_password
    post "sign_up/password", to: "registrations#create_password"
    get "sign_up/otp", to: "registrations#otp", as: :sign_up_otp
    post "sign_up/otp", to: "registrations#create_otp"
    get "sign_up/verify", to: "registrations#verify", as: :sign_up_verify
    post "sign_up/verify", to: "registrations#submit_verify"
    post "sign_up/resend", to: "registrations#resend", as: :sign_up_resend

    get "sign_in", to: "sessions#new", as: :sign_in
    post "sign_in", to: "sessions#continue"
    get "sign_in/password", to: "sessions#password", as: :sign_in_password
    post "sign_in/password", to: "sessions#create_password"
    get "sign_in/otp", to: "sessions#otp", as: :sign_in_otp
    post "sign_in/otp", to: "sessions#create_otp"
    get "sign_in/verify", to: "sessions#verify", as: :sign_in_verify
    post "sign_in/verify", to: "sessions#submit_verify"
    post "sign_in/resend", to: "sessions#resend", as: :sign_in_resend
  end
end
