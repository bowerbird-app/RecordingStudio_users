# frozen_string_literal: true

require "test_helper"
require "cgi"
require "devise/test/integration_helpers"

class OtpDirectChallengeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  EVENT = RecordingStudioUser::RegistrationCompleted::EVENT

  setup do
    @events = []
    @subscriber = ActiveSupport::Notifications.subscribe(EVENT) do |_name, _start, _finish, _id, payload|
      @events << payload
    end
    @config = RecordingStudioUser.config
    @originals = {
      otp_enabled: @config.otp_enabled,
      otp_registration_enabled: @config.otp_registration_enabled,
      otp_login_enabled: @config.otp_login_enabled,
      primary_login_type: @config.primary_login_type,
      registration_authentication_methods: @config.registration_authentication_methods.dup
    }
    Rails.cache.clear
  end

  teardown do
    ActiveSupport::Notifications.unsubscribe(@subscriber)
    restore_otp_config!
    Rails.application.reload_routes!
  end

  test "an existing person gets a code page and returns to the safe path" do
    user = password_user("direct-login")

    assert_no_difference -> { User.count } do
      post recording_studio_user_otp_start_path, params: {
        email: user.email,
        return_to: "/after-direct-login"
      }
    end

    assert_redirected_to recording_studio_user_otp_challenge_path
    refute_includes response.location.to_s, user.email
    follow_redirect!

    assert_response :success
    assert_code_page(user.email)
    assert_equal "DENY", response.headers["X-Frame-Options"]
    assert_includes response.headers["Content-Security-Policy"], "frame-ancestors 'none'"
    assert_select "a[href*='return_to'][href*='after-direct-login']"
    code = login_code(user)
    refute_includes response.body, code

    post recording_studio_user_otp_challenge_path, params: { code: code }

    assert_redirected_to "/after-direct-login"
    assert_empty @events
  end

  test "a new address creates an account, accepts signup terms, and returns" do
    ensure_live_terms!
    email = "direct-new-#{SecureRandom.hex(4)}@example.com"

    assert_difference -> { User.count }, +1 do
      post recording_studio_user_otp_start_path, params: {
        email: email,
        return_to: "/after-direct-signup"
      }
    end
    assert_redirected_to recording_studio_user_otp_challenge_path
    follow_redirect!
    assert_code_page(email)
    assert_includes CGI.unescapeHTML(response.body), "By continuing, you agree"
    assert_select "input[name=accept_terms]", count: 0

    user = User.find_by!(email: email)
    code = registration_code(user)
    refute_includes response.body, code

    post recording_studio_user_otp_challenge_path, params: { code: code }

    assert_redirected_to "/after-direct-signup"
    assert user.reload.confirmed?
    assert_equal [ { user_id: user.id, method: :otp } ], @events
    assert RecordingStudioTermsAndConditions.accepted?(user, Dummy::SignupTerms.workspace)
    receipt = RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last
    assert_equal({ "source" => "continue_notice" }, receipt.provenance)
  end

  test "popup completion follows a direct code" do
    user = password_user("direct-popup")

    post recording_studio_user_otp_start_path, params: {
      email: user.email,
      return_to: "/after-direct-popup",
      popup: "1"
    }
    follow_redirect!
    post recording_studio_user_otp_challenge_path, params: { code: login_code(user) }

    assert_response :success
    assert_includes response.body, "recording_studio_user:signed_in"
    assert_includes response.body, "/after-direct-popup"
    refute_includes response.body, '"*"'
    refute_includes response.body, "'*'"
  end

  test "a known address and an unknown address get the same response" do
    user = password_user("direct-same")
    unknown = "direct-unknown-#{SecureRandom.hex(4)}@example.com"

    post recording_studio_user_otp_start_path, params: {
      email: user.email,
      return_to: "/after-same"
    }
    known_notice = flash[:notice]
    assert_redirected_to recording_studio_user_otp_challenge_path
    follow_redirect!
    known_page = response.body

    post recording_studio_user_otp_start_path, params: {
      email: unknown,
      return_to: "/after-same"
    }
    assert_equal known_notice, flash[:notice]
    assert_redirected_to recording_studio_user_otp_challenge_path
    follow_redirect!

    assert_includes known_page, "Enter your code"
    assert_includes response.body, "Enter your code"
    assert_includes response.body, masked(unknown)
    refute_includes response.body, unknown
    refute_includes known_page, user.email
  end

  test "otp off, registration off, a bad return path, GET, and a missing CSRF token are refused" do
    disable_otp!
    Rails.application.reload_routes!

    post "/users/otp/start", params: { email: "off-#{SecureRandom.hex(4)}@example.com", return_to: "/after" }
    assert_response :not_found

    restore_otp_config!
    Rails.application.reload_routes!
    @config.primary_login_type = :email
    @config.otp_registration_enabled = false
    email = "reg-off-#{SecureRandom.hex(4)}@example.com"

    assert_no_difference -> { User.count } do
      post recording_studio_user_otp_start_path, params: { email: email, return_to: "/after-reg-off" }
    end
    assert_redirected_to recording_studio_user_otp_challenge_path
    assert_nil User.find_by(email: email)

    get recording_studio_user_otp_start_path, params: { email: "get-#{SecureRandom.hex(4)}@example.com" }
    assert_response :not_found

    query_email = "query-#{SecureRandom.hex(4)}@example.com"
    get recording_studio_user_otp_challenge_path, params: { email: query_email }
    refute_includes response.body, query_email
    refute_includes response.location.to_s, query_email

    without_forgery_token do
      post recording_studio_user_otp_start_path, params: {
        email: "csrf-#{SecureRandom.hex(4)}@example.com",
        return_to: "/after-csrf"
      }
      assert_response :unprocessable_entity
    end
  end

  test "an unsafe return path falls back to the default page" do
    user = password_user("direct-bad-return")

    post recording_studio_user_otp_start_path, params: {
      email: user.email,
      return_to: "//evil.com"
    }
    follow_redirect!
    post recording_studio_user_otp_challenge_path, params: { code: login_code(user) }

    assert_redirected_to root_path
  end

  test "login codes stay off when otp login is off" do
    @config.primary_login_type = :email
    @config.registration_authentication_methods = %i[password]
    @config.otp_login_enabled = false
    Rails.application.reload_routes!
    user = password_user("direct-login-off")

    assert_no_difference -> { RecordingStudioUser::OtpChallenge.where(user: user, purpose: "login").count } do
      post recording_studio_user_otp_start_path, params: {
        email: user.email,
        return_to: "/after-login-off"
      }
    end

    assert_redirected_to recording_studio_user_otp_challenge_path
    follow_redirect!
    post recording_studio_user_otp_challenge_path, params: { code: "000000" }

    assert_response :unprocessable_entity
    refute response.redirect?
  end

  test "a direct code request uses the same per-email rate limit" do
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    email = "direct-limit-#{SecureRandom.hex(4)}@example.com"

    post recording_studio_user_otp_start_path, params: { email: email, return_to: "/after-limit" }
    assert_redirected_to recording_studio_user_otp_challenge_path
    code = registration_code(User.find_by!(email: email))

    post recording_studio_user_otp_start_path, params: { email: email, return_to: "/after-limit" }

    assert_response :too_many_requests
    refute response.redirect?
    refute_includes response.body, code
    assert_equal 1, RecordingStudioUser::OtpChallenge.where(
      user: User.find_by!(email: email),
      purpose: "registration"
    ).count
  ensure
    Rails.cache = previous if previous
  end

  private

  def assert_code_page(email)
    assert_select "input[name=code]"
    assert_select "input[type=password]", count: 0
    refute_includes response.body, "Continue with Google"
    refute_includes response.body, email
    assert_includes response.body, masked(email)
    assert_includes response.body, "Use a different email"
    assert_includes response.body, "Resend code"
    assert_select "link[rel=stylesheet][href*='flat_pack']"
  end

  def masked(email)
    local, domain = email.split("@", 2)
    "#{local[0]}***@#{domain}"
  end

  def password_user(label)
    user = RecordingStudioUser.create_user!(
      email: "#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Direct",
      last_name: "Code",
      time_zone: "UTC"
    )
    accept_pending_live_terms!(user)
    user
  end

  def login_code(user)
    open_code(user, "login")
  end

  def registration_code(user)
    open_code(user, "registration")
  end

  def open_code(user, purpose)
    RecordingStudioUser::OtpChallenge.where(user: user, purpose: purpose, consumed_at: nil, revoked_at: nil)
                                     .order(created_at: :desc)
                                     .first!
                                     .decrypt_delivery_code!
  end

  def ensure_live_terms!
    workspace = Dummy::SignupTerms.workspace
    return if RecordingStudioTermsAndConditions.current_published_for(workspace)

    recording = record_terms(Dummy::SignupTerms.root_recording, title: "Signup Terms", body: "Be kind on the way in.")
    publish_terms!(recording, slug: "direct-terms-#{SecureRandom.hex(4)}")
  end

  def without_forgery_token
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  def disable_otp!
    @config.primary_login_type = :email
    @config.otp_enabled = false
  end

  def restore_otp_config!
    @config.otp_enabled = @originals[:otp_enabled]
    @config.otp_login_enabled = @originals[:otp_login_enabled]
    @config.otp_registration_enabled = @originals[:otp_registration_enabled]
    @config.registration_authentication_methods = @originals[:registration_authentication_methods]
    @config.primary_login_type = @originals[:primary_login_type]
  end
end
