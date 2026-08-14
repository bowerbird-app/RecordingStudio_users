# frozen_string_literal: true

RecordingStudioUser::Engine.routes.draw do
  resource :profile, only: %i[show edit update], path: RecordingStudioUser.config.profile_route_path
  get RecordingStudioUser.config.admin_route_path, to: "admin/users#index", as: :admin
  get "#{RecordingStudioUser.config.admin_route_path}/users/:id", to: "admin/users#show", as: :admin_user
end
