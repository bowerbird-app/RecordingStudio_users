# frozen_string_literal: true

# Route configuration must load before Rails draws routes.
RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.mount_path = "/recording_studio_users"
  config.profile_route_path = "profile"
  config.admin_route_path = "admin"
  # Layout for Users screens, including signed-out auth. Leave unset (nil) to
  # use RecordingStudio.configuration.layout, then
  # "recording_studio/default_layout". A String names a layout. false renders
  # with no layout. A callable is invoked as call(controller:) and returns a
  # String, nil, or false.
  # config.layout = "application"
  # :locale is allowlisted by default so a signed-in preferred language can
  # persist for Recording Studio Internationalization. Add more keys with |=
  # so you do not drop locale:
  # config.additional_profile_attributes |= [:nickname]
  config.require_password_confirmation = false
  # Password sign-in allows 5 per email and 10 per IP in 3 minutes.
  # Password reset allows 3 per email and 10 per IP in 15 minutes.
  # The email key is an HMAC of the normalized address. Passwords must be at
  # least minimum_password_length characters (default 12). The user model
  # enforces that. It does not read Devise.password_length.
  # config.password_sign_in_email_limit = 5
  # config.password_sign_in_ip_limit = 10
  # config.password_sign_in_period = 3.minutes
  # config.password_reset_email_limit = 3
  # config.password_reset_ip_limit = 10
  # config.password_reset_period = 15.minutes
  # config.minimum_password_length = 12
  # Sign-in page heading. Leave unset to follow I18n (en: "Welcome back").
  # Hosts add other languages by translating recording_studio_user.* keys.
  # config.login_title = "Welcome back"
  # First auth screen is always email. Next screen follows this setting:
  # :email → password, :otp → email code (requires otp_enabled and OTP flags).
  # config.primary_login_type = :email
  # Site mark on unsigned auth screens. :square (default) or :wide.
  # Blank wide omits the mark.
  # config.auth_logo = :square
  # Markup at the start of every unsigned auth page body. Leave unset (default)
  # when you do not need it. A view that already filled
  # content_for :recording_studio_user_auth_body_start wins, so the partial
  # is not rendered twice.
  # config.auth_body_start_partial = "shared/views_tracking"
  # Partial paths rendered next to the submit button on signup and other
  # unsigned auth forms. Default is an empty list, which renders nothing.
  # Same path style as auth_body_start_partial.
  # config.signup_notice_partials = ["shared/signup_notice"]
  # Where people land after sign-in or sign-up. Default nil keeps the stored
  # return path, or the host root. The callable receives controller: and user:
  # and returns a path or nil. Password, OAuth, one-time code, and the
  # sign-in link all use it, including finishing sign-up.
  # config.after_auth_path = ->(controller:, user:) { "/welcome" }
  # OmniAuth. Leave this empty: Continue-with buttons appear only for providers
  # whose secrets are present in Rails credentials (`omniauth:`). Commented or
  # blank credential keys stay hidden. Do not use ENV or OmniAuth test mode in
  # the app. Add the YAML below with `bin/rails credentials:edit`.
  #
  # omniauth:
  #   google_oauth2:
  #     client_id: your-google-client-id
  #     client_secret: your-google-client-secret
  #   microsoft_graph:
  #     client_id: your-microsoft-client-id
  #     client_secret: your-microsoft-client-secret
  #   apple:
  #     client_id: your-apple-client-id
  #     client_secret: ""
  #     team_id: your-apple-team-id
  #     key_id: your-apple-key-id
  #     pem: |
  #       -----BEGIN PRIVATE KEY-----
  #       ...
  #       -----END PRIVATE KEY-----
  #   linkedin:
  #     client_id: your-linkedin-client-id
  #     client_secret: your-linkedin-client-secret
  #   instagram:
  #     client_id: your-instagram-client-id
  #     client_secret: your-instagram-client-secret
  #
  # Email caveats (Users requires email on first login — MissingEmailError fail-closed):
  # - Automatic matching-email links reject provider emails explicitly marked unverified.
  #   If User supports Devise Confirmable, the existing email must also be confirmed.
  # - Instagram often returns no email. Connect while signed in still works; do not invent emails.
  # - Apple may send email only once (or a private relay). Later visits match Identity by uid.
  # Instagram uses omniauth-instagram-api (Instagram Login client id/secret).
  # Apple often uses client_secret: "" with team_id / key_id / pem options.
  config.omniauth_providers = {}
  # When false, unknown provider emails do not create a User (fail closed).
  config.omniauth_create_account = true
  # Optional email OTP. Leave false unless the host has run OTP migrations
  # and installed recording_studio_notifications. Set primary_login_type = :otp
  # only when OTP login and registration are on.
  config.otp_enabled = false
  # Account lockout. Failures in the window pause that sign-in method for the
  # duration. A correct code or password during the pause looks like a normal
  # miss. Code and password pauses are separate. One email is sent when a
  # pause starts. While codes are paused, a code request emails a one-time
  # sign-in link (digest only, expires with otp_expires_in) instead of a code.
  # The sent notice does not change. Following the link signs that user in and
  # clears both pauses. A completed password reset also clears the password
  # pause.
  # Code and password limits need a shared cache (Redis or Memcached). A
  # memory store, a null store, or a file store raises at boot outside
  # development and test. Development and test log a warning. Code limits
  # raise only when otp_enabled is true.
  # config.otp_lockout_max_failures = 10
  # config.otp_lockout_window = 1.hour
  # config.otp_lockout_duration = 1.hour
  # config.password_lockout_max_failures = 10
  # config.password_lockout_window = 1.hour
  # config.password_lockout_duration = 1.hour
  # Optional host callbacks after successful sign-up (password, OAuth new-user,
  # or OTP). Callable or class-name string responding to .call(user:, method:).
  # Multiple registrations are allowed. Errors are logged and reported; sign-up
  # continues. Does not fire on login or identity linking. Put continue-notice
  # copy in signup_notice_partials and record acceptance from this hook.
  # config.after_registration ->(user:, method:) { }
  # config.after_registration "Host::AfterRegistration"
end

# Host Devise must skip sessions/registrations/passwords and mount Users auth:
#   devise_for :users,
#              skip: %i[sessions registrations passwords],
#              controllers: {
#                confirmations: "recording_studio_user/auth/confirmations",
#                omniauth_callbacks: "recording_studio_user/omniauth_callbacks"
#              }
#   recording_studio_user_auth_for :users
#
# Register RecordingStudioUser::People and RecordingStudioUser::Profile in
# RecordingStudio.configure { |c| c.recordable_types = [...] }, then run:
#   bin/rails generate recording_studio_user:migrations
#   bin/rails db:migrate
