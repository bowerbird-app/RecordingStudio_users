# frozen_string_literal: true

RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.layout = "recording_studio/default_layout"
  # All five providers enabled for the reference app. OmniAuth test mode mocks
  # live in config/initializers/omniauth.rb so CI/screenshots need no live apps.
  #
  # Email caveats (fail closed on first login without email — MissingEmailError):
  # - Instagram often returns no email; connect-from-profile still works without inventing one.
  # - Apple may send email only on first consent (or a private relay); later logins match by uid.
  # Instagram uses omniauth-instagram-api (Instagram Login app id/secret — not Facebook Login).
  # Apple often uses client_secret: "" plus team_id / key_id / pem strategy options in production.
  config.omniauth_providers = {
    google_oauth2: {
      client_id: ENV.fetch("GOOGLE_CLIENT_ID", "test-google-client-id"),
      client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET", "test-google-client-secret"),
      logo: RecordingStudioUser::Omniauth::GOOGLE_LOGO_SVG
    },
    microsoft_graph: {
      client_id: ENV.fetch("MICROSOFT_CLIENT_ID", "test-microsoft-client-id"),
      client_secret: ENV.fetch("MICROSOFT_CLIENT_SECRET", "test-microsoft-client-secret"),
      logo: RecordingStudioUser::Omniauth::MICROSOFT_LOGO_SVG
    },
    apple: {
      client_id: ENV.fetch("APPLE_CLIENT_ID", "test-apple-client-id"),
      client_secret: ENV.fetch("APPLE_CLIENT_SECRET", ""),
      team_id: ENV.fetch("APPLE_TEAM_ID", "test-apple-team-id"),
      key_id: ENV.fetch("APPLE_KEY_ID", "test-apple-key-id"),
      pem: ENV.fetch("APPLE_PEM", "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----"),
      scope: "email name",
      logo: RecordingStudioUser::Omniauth::APPLE_LOGO_SVG
    },
    linkedin: {
      client_id: ENV.fetch("LINKEDIN_CLIENT_ID", "test-linkedin-client-id"),
      client_secret: ENV.fetch("LINKEDIN_CLIENT_SECRET", "test-linkedin-client-secret"),
      logo: RecordingStudioUser::Omniauth::LINKEDIN_LOGO_SVG
    },
    instagram: {
      client_id: ENV.fetch("INSTAGRAM_CLIENT_ID", "test-instagram-client-id"),
      client_secret: ENV.fetch("INSTAGRAM_CLIENT_SECRET", "test-instagram-client-secret"),
      logo: RecordingStudioUser::Omniauth::INSTAGRAM_LOGO_SVG
    }
  }
  config.omniauth_create_account = true
end
