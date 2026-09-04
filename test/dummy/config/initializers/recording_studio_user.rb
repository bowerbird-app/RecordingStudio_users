# frozen_string_literal: true

RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.layout = "recording_studio/default_layout"
  config.otp_enabled = true
  config.otp_login_enabled = true
  config.otp_registration_enabled = true
  config.registration_authentication_methods = %i[password otp]
  config.primary_login_type = :otp
  config.password_registration_confirmation = :existing_policy
  # OmniAuth buttons follow Rails credentials under `omniauth:`. Leave this hash
  # empty so a filled client_id / client_secret shows that provider, and a
  # commented or blank provider stays hidden. Dummy development credentials keep
  # live Google keys and commented examples for the other four.
  #
  # Redirect URI: http://localhost:3000/users/auth/google_oauth2/callback
  #
  # Email caveats (fail closed on first login without email — MissingEmailError):
  # - Instagram often returns no email; connect-from-profile still works without inventing one.
  # - Apple may send email only on first consent (or a private relay); later logins match by uid.
  # Instagram uses omniauth-instagram-api (Instagram Login app id/secret — not Facebook Login).
  # Apple often uses client_secret: "" plus team_id / key_id / pem strategy options in production.
  config.omniauth_create_account = true
end
