# frozen_string_literal: true

RecordingStudioUsers::Engine.routes.draw do
  root "memberships#index"
  resources :memberships, only: %i[create update destroy]
end
