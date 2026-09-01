# frozen_string_literal: true

RecordingStudioUser::Engine.routes.draw do
  resource :profile, only: %i[show edit update], path: RecordingStudioUser.config.profile_route_path
  get RecordingStudioUser.config.admin_route_path, to: "admin/users#index", as: :admin

  scope module: :auth, path: "auth" do
    get "sign_up", to: "registrations#new", as: :sign_up
    get "sign_up/password", to: "registrations#password", as: :sign_up_password
    post "sign_up/password", to: "registrations#create_password"
    get "sign_up/otp", to: "registrations#otp", as: :sign_up_otp
    post "sign_up/otp", to: "registrations#create_otp"
    get "sign_up/verify", to: "registrations#verify", as: :sign_up_verify
    post "sign_up/verify", to: "registrations#submit_verify"
    post "sign_up/resend", to: "registrations#resend", as: :sign_up_resend

    get "sign_in", to: "sessions#new", as: :sign_in
    get "sign_in/password", to: "sessions#password", as: :sign_in_password
    post "sign_in/password", to: "sessions#create_password"
    get "sign_in/otp", to: "sessions#otp", as: :sign_in_otp
    post "sign_in/otp", to: "sessions#create_otp"
    get "sign_in/verify", to: "sessions#verify", as: :sign_in_verify
    post "sign_in/verify", to: "sessions#submit_verify"
    post "sign_in/resend", to: "sessions#resend", as: :sign_in_resend
  end
end
