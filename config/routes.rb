# frozen_string_literal: true

RecordingStudioUsers::Engine.routes.draw do
  root to: "onboarding#show"
  get "onboarding", to: "onboarding#show", as: :onboarding
  post "onboarding", to: "onboarding#create"

  resources :invitations, only: %i[index create]
  get "invitations/accept/:token", to: "invitations#accept", as: :accept_invitation
  post "invitations/accept/:token", to: "invitations#redeem", as: :redeem_invitation

  resources :memberships, only: %i[update destroy]
  resource :operating_role, only: :update
end
