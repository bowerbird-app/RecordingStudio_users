# frozen_string_literal: true

RecordingStudioNotificationsPush::Engine.routes.draw do
  resource :devices, only: [:show]
  delete "devices/:id", to: "devices#destroy", as: :device
  resources :installations, only: %i[create destroy] do
    member do
      post :test_push
    end
  end
end
