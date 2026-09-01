# frozen_string_literal: true

# Credentials first, then ENV, then dummy-only test fallbacks so CI boots without secrets.
omniauth_secret = lambda do |*path, env:, fallback: nil|
  Rails.application.credentials.dig(:omniauth, *path).presence || ENV[env].presence || fallback
end

RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.layout = "recording_studio/default_layout"
  # All five providers enabled for the reference app. OmniAuth test mode mocks
  # live in config/initializers/omniauth.rb so CI/screenshots need no live apps.
  #
  # Development Google login: put client_id / client_secret in
  # config/credentials/development.yml.enc, then start the server without
  # OMNIAUTH_TEST_MODE. Redirect URI: http://localhost:3000/users/auth/google_oauth2/callback
  #
  # Email caveats (fail closed on first login without email — MissingEmailError):
  # - Instagram often returns no email; connect-from-profile still works without inventing one.
  # - Apple may send email only on first consent (or a private relay); later logins match by uid.
  # Instagram uses omniauth-instagram-api (Instagram Login app id/secret — not Facebook Login).
  # Apple often uses client_secret: "" plus team_id / key_id / pem strategy options in production.
  config.omniauth_providers = {
    google_oauth2: {
      client_id: omniauth_secret.call(:google_oauth2, :client_id, env: "GOOGLE_CLIENT_ID",
                                                              fallback: "test-google-client-id"),
      client_secret: omniauth_secret.call(:google_oauth2, :client_secret, env: "GOOGLE_CLIENT_SECRET",
                                                                    fallback: "test-google-client-secret"),
      logo: RecordingStudioUser::Omniauth::GOOGLE_LOGO_SVG
    },
    microsoft_graph: {
      client_id: omniauth_secret.call(:microsoft_graph, :client_id, env: "MICROSOFT_CLIENT_ID",
                                                                fallback: "test-microsoft-client-id"),
      client_secret: omniauth_secret.call(:microsoft_graph, :client_secret, env: "MICROSOFT_CLIENT_SECRET",
                                                                      fallback: "test-microsoft-client-secret"),
      logo: RecordingStudioUser::Omniauth::MICROSOFT_LOGO_SVG
    },
    apple: {
      client_id: omniauth_secret.call(:apple, :client_id, env: "APPLE_CLIENT_ID",
                                                       fallback: "test-apple-client-id"),
      client_secret: omniauth_secret.call(:apple, :client_secret, env: "APPLE_CLIENT_SECRET", fallback: ""),
      team_id: omniauth_secret.call(:apple, :team_id, env: "APPLE_TEAM_ID", fallback: "test-apple-team-id"),
      key_id: omniauth_secret.call(:apple, :key_id, env: "APPLE_KEY_ID", fallback: "test-apple-key-id"),
      pem: omniauth_secret.call(:apple, :pem, env: "APPLE_PEM",
                                            fallback: "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----"),
      scope: "email name",
      logo: RecordingStudioUser::Omniauth::APPLE_LOGO_SVG
    },
    linkedin: {
      client_id: omniauth_secret.call(:linkedin, :client_id, env: "LINKEDIN_CLIENT_ID",
                                                          fallback: "test-linkedin-client-id"),
      client_secret: omniauth_secret.call(:linkedin, :client_secret, env: "LINKEDIN_CLIENT_SECRET",
                                                                fallback: "test-linkedin-client-secret"),
      logo: RecordingStudioUser::Omniauth::LINKEDIN_LOGO_SVG
    },
    instagram: {
      client_id: omniauth_secret.call(:instagram, :client_id, env: "INSTAGRAM_CLIENT_ID",
                                                            fallback: "test-instagram-client-id"),
      client_secret: omniauth_secret.call(:instagram, :client_secret, env: "INSTAGRAM_CLIENT_SECRET",
                                                                  fallback: "test-instagram-client-secret"),
      logo: RecordingStudioUser::Omniauth::INSTAGRAM_LOGO_SVG
    }
  }
  config.omniauth_create_account = true
end
