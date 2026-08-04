# frozen_string_literal: true

RecordingStudioUsers::Engine.routes.draw do
  resource :profile, only: %i[show edit update], controller: "profiles" do
    post :avatar, action: :upload_avatar
    patch :avatar, action: :replace_avatar
    delete :avatar, action: :remove_avatar
    get :security
  end

  resources :users, only: [] do
    collection { get :search }
  end

  root "profiles#show"
end
