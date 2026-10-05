# frozen_string_literal: true

module Dummy
  # Dummy-only OmniAuth placeholders so Devise callback routes load when the
  # shared master key is missing. Hosts leave `omniauth_providers` empty.
  module OmniauthFallbacks
    PLACEHOLDER = "dev_placeholder"
    GOOGLE = {
      google_oauth2: {
        client_id: PLACEHOLDER,
        client_secret: PLACEHOLDER
      }
    }.freeze
    ALL = GOOGLE.merge(
      microsoft_graph: {
        client_id: PLACEHOLDER,
        client_secret: PLACEHOLDER
      },
      apple: {
        client_id: PLACEHOLDER,
        client_secret: PLACEHOLDER,
        team_id: PLACEHOLDER,
        key_id: PLACEHOLDER,
        pem: PLACEHOLDER
      },
      linkedin: {
        client_id: PLACEHOLDER,
        client_secret: PLACEHOLDER
      },
      instagram: {
        client_id: PLACEHOLDER,
        client_secret: PLACEHOLDER
      }
    ).freeze

    module_function

    def providers
      from_credentials = RecordingStudioUser::Omniauth.providers_from_credentials
      return from_credentials if from_credentials.present?

      Rails.env.test? ? ALL : GOOGLE
    end
  end
end

RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.layout = "recording_studio/default_layout"
  config.otp_enabled = true
  config.otp_login_enabled = true
  config.otp_registration_enabled = true
  config.registration_authentication_methods = %i[password otp]
  # config.primary_login_type = :otp # default :email — password on screen 2
  config.password_registration_confirmation = :existing_policy
  # OmniAuth. Hosts leave this empty: Continue-with buttons appear only for
  # providers whose secrets are present in Rails credentials (`omniauth:`).
  # Dummy prefers decrypted credentials, then falls back to placeholders so
  # Devise OmniAuth callbacks still load when the shared master key is unset
  # (CI and a fresh clone). Do not copy this into a host. Do not use
  # environment-variable secrets or OmniAuth test mode in the app.
  #
  # Dummy development credentials keep Google live and comment the other four.
  # Dummy test credentials keep all five live. Fallback matches that split.
  #
  # Redirect URI: http://localhost:3000/users/auth/google_oauth2/callback
  #
  # Email caveats (fail closed on first login without email — MissingEmailError):
  # - Instagram often returns no email; connect-from-profile still works without inventing one.
  # - Apple may send email only on first consent (or a private relay); later logins match by uid.
  # Instagram uses omniauth-instagram-api (Instagram Login app id/secret — not Facebook Login).
  # Apple often uses client_secret: "" plus team_id / key_id / pem strategy options in production.
  config.omniauth_providers = Dummy::OmniauthFallbacks.providers
  config.omniauth_create_account = true
end
