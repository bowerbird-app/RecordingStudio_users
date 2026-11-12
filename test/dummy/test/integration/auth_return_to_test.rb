# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AuthReturnToTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include RecordingStudioUser::AuthRoutesHelper

  setup do
    OmniAuth.config.test_mode = true
    @popup_origins = RecordingStudioUser.config.popup_opener_origins.dup
  end

  teardown do
    RecordingStudioUser.config.popup_opener_origins = @popup_origins
    clear_provider_mock!
  end

  test "sign in page keeps a return path and refuses frames" do
    get new_user_session_path, params: { return_to: "/after-sign-in", popup: "1" }

    assert_response :success
    assert_select "link[rel=stylesheet][href*='flat_pack']"
    assert_equal "DENY", response.headers["X-Frame-Options"]
    assert_includes response.headers["Content-Security-Policy"], "frame-ancestors 'none'"
    assert_select "a[href*='return_to'][href*='popup=1']"
  end

  test "password sign in returns to a safe path" do
    user = password_user("return-password")

    get new_user_session_path, params: { return_to: "/after-password" }
    post new_user_session_path, params: { user: { email: user.email } }
    assert_redirected_to "#{new_user_session_path}/password"

    post user_session_path, params: { user: { email: user.email, password: "Password123!" } }

    assert_redirected_to "/after-password"
  end

  test "unsafe return paths fall back to the default page" do
    user = password_user("return-denied")
    denied = [
      "https://evil.com",
      "//evil.com",
      "/\\evil.com",
      "javascript:alert(1)",
      "/%2F%2Fevil.com",
      "/foo\\bar",
      "/ok\r\nLocation: https://evil.com",
      "/#{"b" * 2048}",
      "",
      "   "
    ]

    denied.each do |return_to|
      sign_out :user
      post user_session_path, params: {
        user: { email: user.email, password: "Password123!" },
        return_to: return_to
      }

      assert_redirected_to root_path, "expected #{return_to.inspect} to fall back"
    end

    sign_out :user
    post user_session_path, params: { user: { email: user.email, password: "Password123!" } }

    assert_redirected_to root_path
  end

  test "otp sign in returns to a safe path and still rate limits" do
    user = password_user("return-otp")
    post "#{new_user_session_path}/otp", params: { user: { email: user.email }, return_to: "/after-otp" }
    follow_redirect!
    post resend_user_session_path, params: { return_to: "/after-otp" }
    assert_redirected_to verify_user_session_path

    post verify_user_session_path, params: { code: login_code(user), return_to: "/after-otp" }

    assert_redirected_to "/after-otp"

    sign_out :user
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    email = "return-throttled-#{SecureRandom.hex(4)}@example.com"
    digest = RecordingStudioUser::Services::OtpRateLimiter.email_key(email)
    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: digest)

    post "#{new_user_registration_path}/otp", params: {
      user: { email: email },
      return_to: "/after-throttled"
    }

    assert_response :too_many_requests
    refute response.redirect?
  ensure
    Rails.cache = previous if previous
  end

  test "password sign up returns to a safe path and still shows terms" do
    email = "return-signup-#{SecureRandom.hex(4)}@example.com"
    post new_user_registration_path, params: { user: { email: email }, return_to: "/after-signup" }
    assert_redirected_to "#{new_user_registration_path}/password"
    follow_redirect!

    assert_response :success
    assert_match(/term|continu/i, response.body)

    post user_registration_path, params: {
      user: { email: email, password: "Password123!", password_confirmation: "Password123!" }
    }

    assert_redirected_to "/after-signup"
  end

  test "oauth sign in returns to the path stored before the provider hop" do
    user = password_user("return-oauth")
    mock_provider!(uid: "return-oauth-#{SecureRandom.hex(4)}", email: user.email)

    post "#{user_google_oauth2_omniauth_authorize_path}?return_to=/after-oauth"
    assert_response :redirect
    refute_includes response.location, "return_to"
    follow_redirect!

    assert_redirected_to "/after-oauth"
  end

  test "password reset and confirmation keep a safe return path" do
    user = password_user("return-reset")
    raw_token, encrypted_token = Devise.token_generator.generate(User, :reset_password_token)
    user.update_columns(reset_password_token: encrypted_token, reset_password_sent_at: Time.current)

    get edit_user_password_path(reset_password_token: raw_token, return_to: "/after-reset")
    put user_password_path, params: {
      user: {
        reset_password_token: raw_token,
        password: "BrandNewPassword123!",
        password_confirmation: "BrandNewPassword123!"
      }
    }

    assert_redirected_to "/after-reset"

    sign_out :user
    get new_user_confirmation_path, params: { return_to: "/after-confirm" }
    post user_session_path, params: {
      user: { email: user.email, password: "BrandNewPassword123!" }
    }

    assert_redirected_to "/after-confirm"
  end

  test "popup completion posts only to an allowed origin" do
    user = password_user("return-popup")
    RecordingStudioUser.config.popup_opener_origins = ["https://embed.example"]

    post user_session_path, params: {
      user: { email: user.email, password: "Password123!" },
      return_to: "/after-popup",
      popup: "1"
    }

    assert_response :success
    assert_equal "DENY", response.headers["X-Frame-Options"]
    assert_includes response.headers["Content-Security-Policy"], "frame-ancestors 'none'"
    assert_includes response.body, "recording_studio_user:signed_in"
    assert_includes response.body, "https://embed.example"
    assert_includes response.body, "http://www.example.com"
    assert_includes response.body, "/after-popup"
    refute_includes response.body, '"*"'
    refute_includes response.body, "'*'"
    assert_select "link[rel=stylesheet][href*='flat_pack']"
    assert_select "h2", text: "You're in"
  end

  test "disabled otp and oauth signup stay blocked when return_to is present" do
    original_otp = RecordingStudioUser.config.otp_enabled
    original_primary = RecordingStudioUser.config.primary_login_type
    original_create = RecordingStudioUser.config.omniauth_create_account
    RecordingStudioUser.config.primary_login_type = :email
    RecordingStudioUser.config.otp_enabled = false
    Rails.application.reload_routes!

    get "#{new_user_session_path}/otp", params: { return_to: "/after-otp" }
    assert_response :not_found
    get "#{new_user_registration_path}/otp", params: { return_to: "/after-signup" }
    assert_response :not_found

    user = password_user("return-otp-off")
    post user_session_path, params: {
      user: { email: user.email, password: "Password123!" },
      return_to: "/after-password-otp-off"
    }
    assert_redirected_to "/after-password-otp-off"

    sign_out :user
    RecordingStudioUser.config.omniauth_create_account = false
    mock_provider!(uid: "blocked-#{SecureRandom.hex(4)}", email: "blocked-#{SecureRandom.hex(4)}@example.com")

    assert_no_difference -> { User.count } do
      get user_google_oauth2_omniauth_callback_path, params: { return_to: "/after-oauth" }
    end
    assert_redirected_to new_user_session_path
  ensure
    RecordingStudioUser.config.otp_enabled = original_otp
    RecordingStudioUser.config.primary_login_type = original_primary
    RecordingStudioUser.config.omniauth_create_account = original_create
    Rails.application.reload_routes!
  end

  test "callers build a sign in or sign up path" do
    sign_in = recording_studio_user_sign_in_path(return_to: "/after-helper")
    sign_up = RecordingStudioUser.auth_url_for(:sign_up, return_to: "/after-helper", popup: true)

    assert_includes sign_in, new_user_session_path
    assert_includes sign_up, new_user_registration_path
    assert_includes sign_up, "popup=1"
    assert_equal new_user_session_path, RecordingStudioUser.auth_url_for(:sign_in, return_to: "//evil.com")
  end

  private

  def password_user(label)
    user = RecordingStudioUser.create_user!(
      email: "#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Return",
      last_name: "Path",
      time_zone: "UTC"
    )
    accept_pending_live_terms!(user)
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
      info: { email: email, name: "Return Path", first_name: "Return", last_name: "Path" }
    )
  end

  def clear_provider_mock!
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end
end
