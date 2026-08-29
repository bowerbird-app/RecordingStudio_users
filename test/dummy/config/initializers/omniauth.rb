# frozen_string_literal: true

# OmniAuth test mode so CI and local screenshots do not need a live Google app.
if Rails.env.test? || ENV["OMNIAUTH_TEST_MODE"] == "1"
  OmniAuth.config.test_mode = true
  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
    provider: "google_oauth2",
    uid: "google-uid-dummy",
    info: {
      email: "google.user@example.com",
      name: "Google User",
      first_name: "Google",
      last_name: "User"
    }
  )
end
