# frozen_string_literal: true

RecordingStudioUser::Engine.routes.draw do
  resource :profile, only: %i[show edit update], path: RecordingStudioUser.config.profile_route_path
  get RecordingStudioUser.config.admin_route_path, to: "admin/users#index", as: :admin
end
