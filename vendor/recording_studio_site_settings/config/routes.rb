# frozen_string_literal: true

RecordingStudioSiteSettings::Engine.routes.draw do
  resource :settings, only: %i[show update], controller: "admin/settings"
  root to: "admin/settings#show"
end
