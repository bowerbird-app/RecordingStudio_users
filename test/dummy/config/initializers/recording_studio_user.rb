# frozen_string_literal: true

RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.layout = "recording_studio/default_layout"
  config.omniauth_providers = {
    google_oauth2: {
      client_id: ENV.fetch("GOOGLE_CLIENT_ID", "test-google-client-id"),
      client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET", "test-google-client-secret"),
      # Explicit logo so Sign-in methods is not a text-only row (inline SVG for List::Item icon:).
      logo: RecordingStudioUser::Omniauth::GOOGLE_LOGO_SVG
    }
  }
  config.omniauth_create_account = true
end
