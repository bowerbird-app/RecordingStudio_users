# frozen_string_literal: true

module RecordingStudioUser
  # Engine route groups kept in methods so Metrics/BlockLength can apply.
  module EngineRoutes
    module_function

    def draw(mapper)
      draw_otp_codes(mapper)
      draw_profile(mapper)
      draw_admin(mapper)
      draw_auth(mapper)
    end

    def draw_otp_codes(mapper)
      return unless RecordingStudioUser.config.otp_enabled?

      mapper.resources :otp_codes, only: :show
    end

    def draw_profile(mapper)
      mapper.resource :profile, only: %i[show edit update], path: RecordingStudioUser.config.profile_route_path do
        mapper.get "sign-in-methods", to: "sign_in_methods#show", as: :sign_in_methods
        mapper.resources :identities, only: %i[destroy], param: :provider
      end
    end

    def draw_admin(mapper)
      mapper.get RecordingStudioUser.config.admin_route_path, to: "admin/users#index", as: :admin
    end

    def draw_auth(mapper)
      mapper.scope module: :auth, path: "auth" do
        draw_registration_auth(mapper)
        draw_session_auth(mapper)
        draw_password_auth(mapper)
      end
    end

    def draw_registration_auth(mapper)
      mapper.get "sign_up", to: "registrations#new", as: :sign_up
      mapper.post "sign_up", to: "registrations#continue"
      mapper.get "sign_up/password", to: "registrations#password", as: :sign_up_password
      mapper.post "sign_up/password", to: "registrations#create_password"
      draw_registration_otp(mapper)
    end

    def draw_registration_otp(mapper)
      return unless RecordingStudioUser.config.otp_enabled? && RecordingStudioUser.config.otp_registration_enabled?

      mapper.get "sign_up/otp", to: "registrations#otp", as: :sign_up_otp
      mapper.post "sign_up/otp", to: "registrations#create_otp"
      mapper.get "sign_up/verify", to: "registrations#verify", as: :sign_up_verify
      mapper.post "sign_up/verify", to: "registrations#submit_verify"
      mapper.post "sign_up/resend", to: "registrations#resend", as: :sign_up_resend
    end

    def draw_session_auth(mapper)
      mapper.get "sign_in", to: "sessions#new", as: :sign_in
      mapper.post "sign_in", to: "sessions#continue"
      mapper.get "sign_in/password", to: "sessions#password", as: :sign_in_password
      mapper.post "sign_in/password", to: "sessions#create_password"
      draw_session_otp(mapper)
    end

    def draw_session_otp(mapper)
      return unless RecordingStudioUser.config.otp_enabled? && RecordingStudioUser.config.otp_login_enabled?

      mapper.get "sign_in/otp", to: "sessions#otp", as: :sign_in_otp
      mapper.post "sign_in/otp", to: "sessions#create_otp"
      mapper.get "sign_in/verify", to: "sessions#verify", as: :sign_in_verify
      mapper.post "sign_in/verify", to: "sessions#submit_verify"
      mapper.post "sign_in/resend", to: "sessions#resend", as: :sign_in_resend
    end

    def draw_password_auth(mapper)
      mapper.get "password/new", to: "passwords#new", as: :new_password
      mapper.get "password/edit", to: "passwords#edit", as: :edit_password
      mapper.post "password", to: "passwords#create", as: :password
      mapper.match "password", to: "passwords#update", via: %i[put patch]
    end
  end
end
