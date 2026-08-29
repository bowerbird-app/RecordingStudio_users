# frozen_string_literal: true

# OmniAuth test mode so CI and local screenshots do not need live provider apps.
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

  OmniAuth.config.mock_auth[:microsoft_graph] = OmniAuth::AuthHash.new(
    provider: "microsoft_graph",
    uid: "microsoft-uid-dummy",
    info: {
      email: "microsoft.user@example.com",
      name: "Microsoft User",
      first_name: "Microsoft",
      last_name: "User"
    }
  )

  OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
    provider: "apple",
    uid: "apple-uid-dummy",
    info: {
      email: "apple.user@example.com",
      name: "Apple User",
      first_name: "Apple",
      last_name: "User"
    }
  )

  OmniAuth.config.mock_auth[:linkedin] = OmniAuth::AuthHash.new(
    provider: "linkedin",
    uid: "linkedin-uid-dummy",
    info: {
      email: "linkedin.user@example.com",
      name: "LinkedIn User",
      first_name: "LinkedIn",
      last_name: "User"
    }
  )

  # Instagram API with Instagram Login typically has no email in the auth hash.
  OmniAuth.config.mock_auth[:instagram] = OmniAuth::AuthHash.new(
    provider: "instagram",
    uid: "instagram-uid-dummy",
    info: {
      name: "Instagram User",
      nickname: "instagram.user"
    }
  )
end
