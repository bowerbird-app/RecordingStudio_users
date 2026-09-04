# frozen_string_literal: true

module ActionDispatch
  module Routing
    class Mapper
      # Mount Users password and OTP auth screens with Devise-compatible route names.
      #
      #   devise_for :users,
      #              skip: %i[sessions registrations passwords],
      #              controllers: { omniauth_callbacks: "recording_studio_user/omniauth_callbacks" }
      #   recording_studio_user_auth_for :users
      #
      # Draws `/users/sign_in`, `/users/sign_up`, password reset, and OTP routes.
      # First screens are email-only. Password or OTP follows `primary_login_type`.
      # Password screens work with `otp_enabled` off. OTP actions stay gated.
      def recording_studio_user_auth_for(name = :users, path: nil, **)
        singular = name.to_s.singularize
        mount_path = path || name.to_s
        draw_recording_studio_user_auth_screens(singular, mount_path)
        draw_recording_studio_user_auth_devise_scope(singular, mount_path)
      end

      private

      def draw_recording_studio_user_auth_screens(singular, mount_path)
        scope module: "recording_studio_user/auth", path: mount_path do
          draw_recording_studio_user_registration_routes(singular)
          draw_recording_studio_user_session_routes(singular)
        end
      end

      def draw_recording_studio_user_registration_routes(singular)
        get "sign_up", to: "registrations#new", as: :"new_#{singular}_registration"
        post "sign_up", to: "registrations#continue"
        get "sign_up/password", to: "registrations#password"
        post "sign_up/password", to: "registrations#create_password", as: :"#{singular}_registration"
        get "sign_up/otp", to: "registrations#otp"
        post "sign_up/otp", to: "registrations#create_otp"
        get "sign_up/verify", to: "registrations#verify", as: :"verify_#{singular}_registration"
        post "sign_up/verify", to: "registrations#submit_verify"
        post "sign_up/resend", to: "registrations#resend", as: :"resend_#{singular}_registration"
      end

      def draw_recording_studio_user_session_routes(singular)
        get "sign_in", to: "sessions#new", as: :"new_#{singular}_session"
        post "sign_in", to: "sessions#continue"
        get "sign_in/password", to: "sessions#password"
        post "sign_in/password", to: "sessions#create_password", as: :"#{singular}_session"
        get "sign_in/otp", to: "sessions#otp"
        post "sign_in/otp", to: "sessions#create_otp"
        get "sign_in/verify", to: "sessions#verify", as: :"verify_#{singular}_session"
        post "sign_in/verify", to: "sessions#submit_verify"
        post "sign_in/resend", to: "sessions#resend", as: :"resend_#{singular}_session"
      end

      def draw_recording_studio_user_auth_devise_scope(singular, mount_path)
        passwords = "recording_studio_user/auth/passwords"
        devise_scope singular.to_sym do
          delete "#{mount_path}/sign_out", to: "devise/sessions#destroy", as: :"destroy_#{singular}_session"
          get "#{mount_path}/password/new", to: "#{passwords}#new", as: :"new_#{singular}_password"
          post "#{mount_path}/password", to: "#{passwords}#create", as: :"#{singular}_password"
        end
      end
    end
  end
end
