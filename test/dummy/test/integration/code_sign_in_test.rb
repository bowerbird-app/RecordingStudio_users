# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class CodeSignInTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @after_auth_path = RecordingStudioUser.config.after_auth_path
    @otp_enabled = RecordingStudioUser.config.otp_enabled
    @otp_login_enabled = RecordingStudioUser.config.otp_login_enabled
    @registration_methods = RecordingStudioUser.config.registration_authentication_methods.dup
    @primary_login_type = RecordingStudioUser.config.primary_login_type
    @cache = Rails.cache
    Rails.cache.clear
  end

  teardown do
    RecordingStudioUser.config.after_auth_path = @after_auth_path
    RecordingStudioUser.config.primary_login_type = :email
    RecordingStudioUser.config.otp_enabled = true
    RecordingStudioUser.config.otp_login_enabled = true
    RecordingStudioUser.config.registration_authentication_methods = @registration_methods
    RecordingStudioUser.config.otp_login_enabled = @otp_login_enabled
    RecordingStudioUser.config.otp_enabled = @otp_enabled
    RecordingStudioUser.config.primary_login_type = @primary_login_type
    Rails.cache = @cache
    Rails.application.reload_routes!
  end

  test "a valid link sends a login code and a correct code signs in to return_to" do
    user = password_user("valid")
    planted = "before-rotation"

    assert_no_difference -> { User.count } do
      assert_difference -> { login_challenges(user).count }, +1 do
        get code_link(user, "/notifications/settings")
        assert_token_left_the_url
        follow_redirect!
      end
    end

    assert_equal user.email, session[:auth_email]

    assert_redirected_to verify_user_session_path
    follow_redirect!

    assert_response :success
    assert_includes response.body, masked(user.email)
    refute_includes response.body, user.email
    assert_equal "login", session[:otp_purpose]
    session[:planted] = planted

    post verify_user_session_path, params: { code: login_code(user) }

    assert_redirected_to "/notifications/settings"
    assert_nil session[:planted]
    assert_equal user.id, session["warden.user.user.key"]&.dig(0, 0)
  end

  test "code sign in url is a host link and the path variant omits the host" do
    user = password_user("url")
    url = RecordingStudioUser.code_sign_in_url(user: user, return_to: "/notifications/settings")
    path = RecordingStudioUser.code_sign_in_path(user: user, return_to: "/notifications/settings")

    assert_match %r{\Ahttp://example.com/users/sign_in/code\?code_sign_in_token=}, url
    assert_match %r{\A/users/sign_in/code\?code_sign_in_token=}, path
    refute_includes path, "example.com"
  end

  test "the same signed-in user skips the code and lands on return_to" do
    user = password_user("same")
    sign_in user

    assert_no_difference -> { login_challenges(user).count } do
      get code_link(user, "/notifications/settings")
      assert_token_left_the_url
      follow_redirect!
    end

    assert_redirected_to "/notifications/settings"
    assert_equal user.id, session["warden.user.user.key"]&.dig(0, 0)
  end

  test "an already signed-in person goes to return_to when after_auth_path is set" do
    user = password_user("same-configured")
    RecordingStudioUser.config.after_auth_path = ->(controller:, user:) { "/welcome-host" }
    sign_in user

    get code_link(user, "/notifications/settings")
    follow_redirect!

    assert_redirected_to "/notifications/settings"
  end

  test "a different signed-in user is not switched and can sign out to continue" do
    target = password_user("target")
    other = password_user("other")
    sign_in other

    get code_link(target, "/notifications/settings")
    assert_token_left_the_url
    follow_redirect!

    assert_response :success
    assert_includes response.body, masked(target.email)
    refute_includes response.body, target.email
    refute_includes response.body, "code_sign_in_token"
    assert_equal other.id, session["warden.user.user.key"]&.dig(0, 0)
    assert_select "button", text: I18n.t("recording_studio_user.auth.code_sign_in.sign_out_and_continue")

    assert_difference -> { login_challenges(target).count }, +1 do
      post user_code_sign_in_path
      assert_response :see_other
      refute_includes response.location.to_s, "code_sign_in_token"
      follow_redirect!
    end

    assert_nil session["warden.user.user.key"]
    assert_redirected_to verify_user_session_path
    follow_redirect!
    post verify_user_session_path, params: { code: login_code(target) }

    assert_redirected_to "/notifications/settings"
    assert_equal target.id, session["warden.user.user.key"]&.dig(0, 0)
  end

  test "tampered expired wrong-purpose email-changed and password-changed tokens are rejected" do
    user = password_user("reject")
    tampered = tamper(RecordingStudioUser::CodeSignInToken.issue(user: user, return_to: "/notifications/settings"))
    expired = RecordingStudioUser::CodeSignInToken.issue(
      user: user, return_to: "/notifications/settings", expires_in: 1.minute
    )
    wrong_purpose = wrong_purpose_token(user)
    password_changed = RecordingStudioUser::CodeSignInToken.issue(user: user, return_to: "/notifications/settings")

    user.update!(password: "BrandNewPassword123!", password_confirmation: "BrandNewPassword123!")
    assert_rejected password_changed

    email_changed = RecordingStudioUser::CodeSignInToken.issue(user: user, return_to: "/notifications/settings")
    user.update_columns(email: "moved-#{SecureRandom.hex(4)}@example.com")
    assert_rejected email_changed
    assert_rejected tampered
    travel 2.minutes do
      assert_rejected expired
    end
    assert_rejected wrong_purpose
  end

  test "an absolute or external return_to is dropped" do
    user = password_user("external")

    ["https://evil.example/phish", "//evil.example", "http://evil.example/phish"].each do |unsafe|
      sign_out :user
      get code_link(user, unsafe)
      follow_redirect!
      assert_redirected_to verify_user_session_path
      post verify_user_session_path, params: { code: login_code(user) }

      assert_redirected_to root_path
      refute_includes response.location.to_s, "evil"
    end
  end

  test "after_auth_path keeps precedence over return_to" do
    user = password_user("configured")
    RecordingStudioUser.config.after_auth_path = ->(controller:, user:) { "/welcome-host" }

    get code_link(user, "/notifications/settings")
    follow_redirect!
    follow_redirect!
    post verify_user_session_path, params: { code: login_code(user) }

    assert_redirected_to "/welcome-host"
  end

  test "the token is filtered from logs" do
    user = password_user("filtered")
    token = token_from(code_link(user, "/notifications/settings"))

    filtered_config = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    assert_equal "[FILTERED]", filtered_config.filter("code_sign_in_token" => token)["code_sign_in_token"]

    get code_link(user, "/notifications/settings")

    logged = request.filtered_parameters["code_sign_in_token"] || request.filtered_parameters[:code_sign_in_token]
    assert_equal "[FILTERED]", logged
    refute_includes request.filtered_parameters.to_s, token
    assert_token_left_the_url
  end

  test "a second open inside the rate limit does not send another code" do
    user = password_user("limited")
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    assert_difference -> { login_challenges(user).count }, +1 do
      get code_link(user, "/notifications/settings")
      follow_redirect!
    end
    assert_redirected_to verify_user_session_path

    assert_no_difference -> { login_challenges(user).count } do
      get code_link(user, "/notifications/settings")
      follow_redirect!
    end

    assert_redirected_to verify_user_session_path
    assert_equal I18n.t("recording_studio_user.auth.wait_for_code"), flash[:alert]
  end

  test "unknown and unconfirmed users get the sign-in screen and no new account" do
    missing = password_user("missing")
    missing_token = RecordingStudioUser::CodeSignInToken.issue(user: missing, return_to: "/notifications/settings")
    delete_user!(missing)

    unconfirmed = RecordingStudioUser.create_user!(
      email: "unconfirmed-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Not",
      last_name: "Yet",
      time_zone: "UTC",
      confirm: false
    )

    assert_no_difference -> { User.count } do
      assert_rejected missing_token
      assert_rejected RecordingStudioUser::CodeSignInToken.issue(user: unconfirmed, return_to: "/sign-up-trap")
    end

    assert_empty login_challenges(unconfirmed)
    refute_match %r{/sign_up}, response.location.to_s
  end

  test "otp disabled and login codes off fall back to sign-in" do
    user = password_user("otp-off")
    token = RecordingStudioUser::CodeSignInToken.issue(user: user, return_to: "/notifications/settings")

    RecordingStudioUser.config.primary_login_type = :email
    RecordingStudioUser.config.otp_enabled = false
    Rails.application.reload_routes!

    assert recognize_code_route?
    assert_no_difference -> { login_challenges(user).count } do
      assert_rejected token
    end

    RecordingStudioUser.config.otp_enabled = true
    RecordingStudioUser.config.registration_authentication_methods = %i[password]
    RecordingStudioUser.config.otp_login_enabled = false
    Rails.application.reload_routes!

    assert recognize_code_route?
    assert_rejected token
    assert_empty login_challenges(user)
  end

  test "the engine route also drops the token on the first get" do
    user = password_user("engine")
    token = RecordingStudioUser::CodeSignInToken.issue(user: user, return_to: "/notifications/settings")

    get recording_studio_users.code_sign_in_path(code_sign_in_token: token)

    assert_response :see_other
    refute_includes response.location.to_s, "code_sign_in_token"
    refute_includes response.location.to_s, token
  end

  private

  def password_user(label)
    user = RecordingStudioUser.create_user!(
      email: "code-sign-in-#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Code",
      last_name: "Sign",
      time_zone: "UTC",
      confirm: true
    )
    accept_pending_live_terms!(user)
    sign_out :user
    user
  end

  def code_link(user, return_to)
    RecordingStudioUser.code_sign_in_path(user: user, return_to: return_to)
  end

  def token_from(path)
    Rack::Utils.parse_query(URI.parse(path).query)["code_sign_in_token"]
  end

  def login_challenges(user)
    RecordingStudioUser::OtpChallenge.where(user: user, purpose: "login")
  end

  def login_code(user)
    login_challenges(user).where(consumed_at: nil, revoked_at: nil).order(created_at: :desc).first!.decrypt_delivery_code!
  end

  def masked(email)
    RecordingStudioUser::OtpCodeForm.mask(email)
  end

  def assert_token_left_the_url
    assert_response :see_other
    refute_includes response.location.to_s, "code_sign_in_token"
    assert session[:code_sign_in_token].present?
  end

  def assert_rejected(token)
    assert_no_difference -> { User.count } do
      get user_code_sign_in_path(code_sign_in_token: token)
    end

    assert_response :see_other
    refute_includes response.location.to_s, "code_sign_in_token"
    refute_includes response.location.to_s, token
    follow_redirect!

    if response.redirect?
      follow_redirect!
    end

    assert_response :success
    assert_equal new_user_session_path, request.path
    assert_equal I18n.t("recording_studio_user.auth.code_sign_in.invalid"), flash[:alert]
    assert_nil session["warden.user.user.key"]
    refute_match %r{/sign_up}, request.fullpath
  end

  def tamper(token)
    flipped = token.dup
    flipped[10] = flipped[10] == "a" ? "b" : "a"
    flipped
  end

  def wrong_purpose_token(user)
    Rails.application.message_verifier(RecordingStudioUser::CodeSignInToken::PURPOSE).generate(
      {
        "user_id" => user.id,
        "email" => user.email,
        "return_to" => "/notifications/settings",
        "salt" => user.authenticatable_salt.to_s
      },
      expires_in: 1.hour,
      purpose: "recording_studio_user/other"
    )
  end

  def delete_user!(user)
    RecordingStudioUser::Profile.where(user_id: user.id).delete_all
    user.delete
  end

  def recognize_code_route?
    Rails.application.routes.recognize_path("/users/sign_in/code", method: :get)
    true
  rescue ActionController::RoutingError
    false
  end
end
