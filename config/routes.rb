# frozen_string_literal: true

RecordingStudioUser::Engine.routes.draw do
  resource :profile, only: %i[show edit update], path: RecordingStudioUser.config.profile_route_path do
    get "sign-in-methods", to: "sign_in_methods#show", as: :sign_in_methods
    resources :identities, only: %i[destroy], param: :provider
  end
  get RecordingStudioUser.config.admin_route_path, to: "admin/users#index", as: :admin
end
