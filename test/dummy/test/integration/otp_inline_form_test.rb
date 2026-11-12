# frozen_string_literal: true

require "cgi"
require "test_helper"
require "devise/test/integration_helpers"

class OtpInlineFormTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  EVENT = RecordingStudioUser::RegistrationCompleted::EVENT
  FRAME = RecordingStudioUser::OtpCodeForm::FRAME_ID

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

  test "a turbo frame signs an existing person in and reports the safe return path" do
    user = password_user("inline-login")
    start_code(user.email, "/after-inline-login")
    get recording_studio_user_otp_challenge_path
    session[:rotation_marker] = "present"

    post recording_studio_user_otp_challenge_path,
         params: { code: login_code(user) },
         headers: frame_headers

    assert_response :success
    refute response.redirect?
    assert_nil session[:rotation_marker]
    assert_includes response.body, "recording_studio_user:signed_in"
    assert_includes response.body, "/after-inline-login"
    assert_equal "DENY", response.headers["X-Frame-Options"]
    assert_nil response.headers["Access-Control-Allow-Origin"]
    assert_empty @events
    get root_path
    assert_response :success
  end

  test "a plain form post still redirects to the validated return path" do
    user = password_user("inline-plain")
    start_code(user.email, "/after-inline-plain")

    post recording_studio_user_otp_challenge_path, params: { code: login_code(user) }

    assert_redirected_to "/after-inline-plain"
  end

  test "json tells the caller the validated return path" do
    user = password_user("inline-json")
    start_code(user.email, "/after-inline-json", json: true)
    assert_equal({ "ok" => true }, response.parsed_body)

    post recording_studio_user_otp_challenge_path,
         params: { code: login_code(user) },
         headers: json_headers

    assert_response :success
    assert_equal "/after-inline-json", response.parsed_body["return_to"]
    assert response.parsed_body["csrf_param"].present?
    assert response.parsed_body["csrf_token"].present?
    refute response.redirect?
  end

  test "inline json verify rotates csrf so the returned token works and the old one fails" do
    with_forgery_protection do
      user = password_user("inline-csrf-rotate")
      get inline_code_demo_path
      param, old_token = csrf_pair

      post recording_studio_user_otp_start_path,
           params: { email: user.email, return_to: "/after-csrf", param => old_token },
           headers: json_headers
      assert_response :success

      post recording_studio_user_otp_challenge_path,
           params: { code: login_code(user), param => old_token },
           headers: json_headers

      assert_response :success
      body = response.parsed_body
      assert_equal param, body["csrf_param"]
      new_token = body["csrf_token"]
      assert new_token.present?

      post recording_studio_user_otp_resend_path,
           params: { param => old_token },
           headers: json_headers
      assert_response :unprocessable_entity

      delete destroy_user_session_path, params: { param => new_token }
      assert_response :redirect
    end
  end

  test "a new address in a turbo frame creates one account and accepts terms" do
    ensure_live_terms!
    email = "inline-new-#{SecureRandom.hex(4)}@example.com"
    start_code(email, "/after-inline-signup")
    user = User.find_by!(email: email)

    post recording_studio_user_otp_challenge_path,
         params: { code: registration_code(user), accept_terms: "1" },
         headers: frame_headers

    assert_response :success
    refute response.redirect?
    assert_includes response.body, "recording_studio_user:signed_in"
    assert_includes response.body, "csrf_param"
    assert_includes response.body, "csrf_token"
    assert_includes response.body, 'meta[name="csrf-token"]'
    assert_includes response.body, "/after-inline-signup"
    assert user.reload.confirmed?
    assert_equal [ { user_id: user.id, method: :otp } ], @events
    assert RecordingStudioTermsAndConditions.accepted?(user, Dummy::SignupTerms.workspace)
    receipt = RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last
    assert_equal({ "source" => "checkbox" }, receipt.provenance)
  end

  test "a missing terms checkbox does not finish a new account" do
    refute_inline_registration_without_terms
  end

  test "an unticked terms checkbox does not finish a new account" do
    refute_inline_registration_without_terms(accept_terms: "0")
  end

  test "a ticked terms checkbox finishes the account and the same code still works after a miss" do
    ensure_live_terms!
    email = "inline-tick-#{SecureRandom.hex(4)}@example.com"
    start_code(email, "/after-inline-tick")
    user = User.find_by!(email: email)
    code = registration_code(user)

    post recording_studio_user_otp_challenge_path,
         params: { code: code },
         headers: json_headers

    assert_response :unprocessable_entity
    refute user.reload.confirmed?

    post recording_studio_user_otp_challenge_path,
         params: { code: code, accept_terms: "1" },
         headers: json_headers

    assert_response :success
    assert_equal true, response.parsed_body["ok"]
    assert user.reload.confirmed?
    receipt = RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last
    assert_equal({ "source" => "checkbox" }, receipt.provenance)
  end

  test "a turbo resend stays in the frame" do
    user = password_user("inline-resend")
    start_code(user.email, "/after-inline-resend")

    post recording_studio_user_otp_resend_path, headers: frame_headers

    assert_response :success
    refute response.redirect?
    assert_select "turbo-frame##{FRAME}"
    assert_includes response.body, "If an eligible account exists, we sent a code."
  end

  test "a known address and an unknown address get the same json" do
    user = password_user("inline-same")
    unknown = "inline-unknown-#{SecureRandom.hex(4)}@example.com"

    post recording_studio_user_otp_start_path,
         params: { email: user.email, return_to: "/after-inline-same" },
         headers: json_headers
    known = response.body

    post recording_studio_user_otp_start_path,
         params: { email: unknown, return_to: "/after-inline-same" },
         headers: json_headers

    assert_response :success
    assert_equal known, response.body
    refute_includes response.body, user.email
    refute_includes response.body, unknown
  end

  test "a wrong turbo code stays in the frame" do
    user = password_user("inline-wrong")
    start_code(user.email, "/after-inline-wrong")

    post recording_studio_user_otp_challenge_path,
         params: { code: "000000" },
         headers: frame_headers

    assert_response :unprocessable_entity
    refute response.redirect?
    assert_select "turbo-frame##{FRAME} input[name=code]"
    assert_includes response.body, "That code did not work"
    get root_path
    assert_redirected_to new_user_session_path
  end

  test "json start is missing when one-time codes are off" do
    disable_otp!
    Rails.application.reload_routes!

    post "/users/otp/start",
         params: { email: "inline-off@example.com", return_to: "/after" },
         headers: json_headers

    assert_response :not_found
  end

  test "registration off does not create an account and still says ok" do
    @config.otp_registration_enabled = false
    Rails.application.reload_routes!
    email = "inline-reg-off-#{SecureRandom.hex(4)}@example.com"

    assert_no_difference -> { User.count } do
      post recording_studio_user_otp_start_path,
           params: { email: email, return_to: "/after-inline-reg-off" },
           headers: json_headers
    end

    assert_response :success
    assert_equal({ "ok" => true }, response.parsed_body)
    assert_nil User.find_by(email: email)
  end

  test "a missing csrf token is rejected" do
    without_forgery_token do
      post recording_studio_user_otp_start_path,
           params: { email: "inline-csrf@example.com", return_to: "/after" },
           headers: json_headers
    end

    assert_response :unprocessable_entity
  end

  test "a foreign origin is forbidden and adds no cors header" do
    email = "inline-origin-#{SecureRandom.hex(4)}@example.com"

    assert_no_difference -> { User.count } do
      post recording_studio_user_otp_start_path,
           params: { email: email, return_to: "/after-inline-origin" },
           headers: json_headers.merge("Origin" => "https://evil.example")
    end

    assert_response :forbidden
    assert_nil response.headers["Access-Control-Allow-Origin"]
    assert_equal "DENY", response.headers["X-Frame-Options"]
    assert_nil User.find_by(email: email)
  end

  test "an unsafe return path falls back to the root" do
    user = password_user("inline-bad-return")
    start_code(user.email, "//evil.com", json: true)

    post recording_studio_user_otp_challenge_path,
         params: { code: login_code(user) },
         headers: json_headers

    assert_response :success
    assert_equal "/", response.parsed_body["return_to"]
    refute_includes response.body, "evil.com"
  end

  test "json start uses the same per-email rate limit" do
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    email = "inline-limit-#{SecureRandom.hex(4)}@example.com"

    post recording_studio_user_otp_start_path,
         params: { email: email, return_to: "/after-inline-limit" },
         headers: json_headers
    assert_response :success
    user = User.find_by!(email: email)

    post recording_studio_user_otp_start_path,
         params: { email: email, return_to: "/after-inline-limit" },
         headers: json_headers

    assert_response :too_many_requests
    assert_equal false, response.parsed_body["ok"]
    assert_equal 1, RecordingStudioUser::OtpChallenge.where(user: user, purpose: "registration").count
  ensure
    Rails.cache = previous if previous
  end

  test "the demo modal holds the code box and the page styles" do
    user = password_user("inline-demo")
    start_code(user.email, "/after-inline-demo")

    get inline_code_demo_path

    assert_response :success
    assert_select "link[rel=stylesheet][href*='flat_pack']"
    assert_select "script[type=importmap]"
    assert_select "[data-modal-id=inline-code-demo]"
    assert_select "#inline-code-demo .flat-pack-modal__header", count: 0
    assert_select "#inline-code-demo .flat-pack-modal__close"
    assert_select "#inline-code-demo h2", text: "Enter your code"
    assert_select "#inline-code-demo turbo-frame##{FRAME}" do
      assert_select ".space-y-6"
      assert_select "form .space-y-4"
      assert_select "form .space-y-6"
      assert_select "input[name=code]"
      assert_select "input[name=accept_terms]", count: 0
      assert_select "input[type=password]", count: 0
      assert_select "button.w-full", text: "Continue"
      assert_select "form[action=?] button.flat-pack-link[type=submit]", recording_studio_user_otp_resend_path, text: "Resend code"
      assert_select "a.flat-pack-link", text: "Use a different email"
      assert_select "button.w-full", text: "Resend code", count: 0
    end
    assert_includes response.body, masked(user.email)
    refute_includes response.body, user.email
    refute_includes response.body, "min-h-dvh"
    refute_includes response.body, "Continue with Google"
  end

  test "a new address shows the terms checkbox in the demo modal" do
    ensure_live_terms!
    email = "inline-box-#{SecureRandom.hex(4)}@example.com"
    start_code(email, "/after-inline-box")

    get inline_code_demo_path

    assert_response :success
    assert_select "link[rel=stylesheet][href*='flat_pack']"
    assert_select "#inline-code-demo input[type=checkbox][name=accept_terms]"
    assert_select "#inline-code-demo label button[type=button][data-modal-id]", text: "Terms & Conditions"
    assert_includes CGI.unescapeHTML(response.body), "I agree to Studio's"
    refute_includes CGI.unescapeHTML(response.body), "By continuing, you agree"
  end

  private

  def start_code(email, return_to, json: false)
    post recording_studio_user_otp_start_path,
         params: { email: email, return_to: return_to },
         headers: json ? json_headers : {}
    return if json

    assert_redirected_to recording_studio_user_otp_challenge_path
  end

  def frame_headers
    { "Turbo-Frame" => FRAME }
  end

  def json_headers
    { "Accept" => "application/json" }
  end

  def masked(email)
    local, domain = email.split("@", 2)
    "#{local[0]}***@#{domain}"
  end

  def password_user(label)
    user = RecordingStudioUser.create_user!(
      email: "#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Inline",
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
    publish_terms!(recording, slug: "inline-terms-#{SecureRandom.hex(4)}")
  end

  def refute_inline_registration_without_terms(extra = {})
    ensure_live_terms!
    email = "inline-deny-#{SecureRandom.hex(4)}@example.com"
    start_code(email, "/after-inline-deny")
    user = User.find_by!(email: email)

    assert_no_difference -> { RecordingStudioTermsAndConditions::Acceptance.count } do
      post recording_studio_user_otp_challenge_path,
           params: { code: registration_code(user) }.merge(extra),
           headers: json_headers
    end

    assert_response :unprocessable_entity
    assert_equal false, response.parsed_body["ok"]
    refute user.reload.confirmed?
    get root_path
    assert_redirected_to new_user_session_path
  end

  def csrf_pair
    param = css_select('meta[name="csrf-param"]').first["content"]
    token = css_select('meta[name="csrf-token"]').first["content"]
    [param, token]
  end

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
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
