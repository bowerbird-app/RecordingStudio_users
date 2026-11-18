# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AfterAuthPathTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  CONFIGURED_PATH = "/after-auth"

  setup do
    OmniAuth.config.test_mode = true
    @after_auth_path = RecordingStudioUser.config.after_auth_path
    @create_account = RecordingStudioUser.config.omniauth_create_account
    RecordingStudioUser.config.omniauth_create_account = true
    Rails.cache.clear
  end

  teardown do
    RecordingStudioUser.config.after_auth_path = @after_auth_path
    RecordingStudioUser.config.omniauth_create_account = @create_account
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  test "password sign in uses the configured path" do
    user = password_user("password")
    use_configured_path!

    post user_session_path, params: { user: { email: user.email, password: "Password123!" } }

    assert_redirected_to CONFIGURED_PATH
  end

  test "oauth sign in uses the configured path" do
    use_configured_path!
    mock_provider!(uid: "after-auth-#{SecureRandom.hex(4)}", email: "oauth-#{SecureRandom.hex(4)}@example.com")

    get user_google_oauth2_omniauth_callback_path

    assert_redirected_to CONFIGURED_PATH
  end

  test "otp sign in uses the configured path" do
    user = password_user("otp")
    use_configured_path!

    post "#{new_user_session_path}/otp", params: { user: { email: user.email } }
    assert_redirected_to verify_user_session_path
    post verify_user_session_path, params: { code: login_code(user) }

    assert_redirected_to CONFIGURED_PATH
  end

  test "sign in link post uses the configured path" do
    user = password_user("link")
    raw, _link = RecordingStudioUser::SignInLink.issue!(user)
    use_configured_path!

    post recording_studio_users.sign_in_link_path, params: { sign_in_token: raw }

    assert_redirected_to CONFIGURED_PATH
  end

  test "nil after auth path falls back to the default page" do
    user = password_user("nil-path")
    RecordingStudioUser.config.after_auth_path = ->(controller:, user:) { nil }

    post user_session_path, params: { user: { email: user.email, password: "Password123!" } }

    assert_redirected_to root_path

    sign_out :user
    RecordingStudioUser.config.after_auth_path = nil
    post user_session_path, params: { user: { email: user.email, password: "Password123!" } }

    assert_redirected_to root_path
  end

  private

  def use_configured_path!
    RecordingStudioUser.config.after_auth_path = ->(controller:, user:) { CONFIGURED_PATH }
  end

  def password_user(label)
    user = RecordingStudioUser.create_user!(
      email: "after-auth-#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "After",
      last_name: "Auth",
      time_zone: "UTC",
      confirm: true
    )
    accept_pending_live_terms!(user)
    sign_out :user
    user
  end

  def login_code(user)
    RecordingStudioUser::OtpChallenge.where(user: user, purpose: "login", consumed_at: nil, revoked_at: nil)
                                     .order(created_at: :desc)
                                     .first!
                                     .decrypt_delivery_code!
  end

  def mock_provider!(uid:, email:)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: email, name: "After Auth", first_name: "After", last_name: "Auth" }
    )
  end
end
