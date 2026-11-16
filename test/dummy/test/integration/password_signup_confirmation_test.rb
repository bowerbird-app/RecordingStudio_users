# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PasswordSignupConfirmationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  PASSWORD = "Password123!"

  setup do
    ActionMailer::Base.deliveries.clear
    Rails.cache.clear
    @config = RecordingStudioUser.config
    @originals = {
      primary_login_type: @config.primary_login_type,
      registration_authentication_methods: @config.registration_authentication_methods.dup,
      otp_enabled: @config.otp_enabled,
      otp_login_enabled: @config.otp_login_enabled,
      otp_registration_enabled: @config.otp_registration_enabled
    }
  end

  teardown do
    @config.otp_enabled = @originals.fetch(:otp_enabled)
    @config.otp_login_enabled = @originals.fetch(:otp_login_enabled)
    @config.otp_registration_enabled = @originals.fetch(:otp_registration_enabled)
    @config.registration_authentication_methods = @originals.fetch(:registration_authentication_methods)
    @config.primary_login_type = @originals.fetch(:primary_login_type)
    Rails.application.reload_routes!
  end

  test "password signup waits for a code and keeps that signup password" do
    email = unique_email("signup")

    post user_registration_path, params: signup_params(email)
    user = User.find_by!(email: email)

    assert_redirected_to verify_user_registration_path
    refute user.confirmed?
    assert user.valid_password?(PASSWORD)
    assert_nil session["warden.user.user.key"]
    assert_equal user.id, session[RecordingStudioUser::PasswordConfirmation::SESSION_KEY]

    submit_signup_code!
    assert_redirected_to root_path
    assert_nil session[RecordingStudioUser::PasswordConfirmation::SESSION_KEY]
    assert user.reload.confirmed?
    assert user.valid_password?(PASSWORD)

    get recording_studio_users.profile_path
    assert_response :success
  end

  test "a different browser confirmation clears the earlier password and remembered sign-in" do
    email = unique_email("other-browser")
    planter = open_session
    planter.post user_registration_path, params: signup_params(email)
    user = User.find_by!(email: email)
    user.update_column(:remember_created_at, Time.current)
    planted_salt = user.authenticatable_salt
    planter.session["warden.user.user.key"] = [[user.id], planted_salt]

    owner = open_session
    owner.post user_session_code_path, params: { user: { email: email } }
    owner.assert_redirected_to verify_user_session_path
    code = RecordingStudioUser.otp_message(owner.session[:otp_challenge_id]).fetch(:body)[/\d{6}/]
    owner.post verify_user_session_path, params: { code: code }

    owner.assert_redirected_to root_path
    user.reload
    assert user.confirmed?
    refute user.valid_password?(PASSWORD)
    assert_equal "", user.encrypted_password
    assert_nil user.remember_created_at
    refute_equal planted_salt, user.authenticatable_salt

    owner.get recording_studio_users.profile_path
    owner.assert_response :success
    planter.get recording_studio_users.profile_path
    planter.assert_redirected_to new_user_session_path
  end

  test "password sign-in refuses an unconfirmed account and the code signs them in" do
    email = unique_email("refused")
    user = User.create!(
      email: email,
      password: PASSWORD,
      password_confirmation: PASSWORD,
      registered_with: "password"
    )
    refute user.confirmed?

    post user_session_path, params: { user: { email: email, password: PASSWORD } }

    assert_response :unprocessable_entity
    assert_equal I18n.t("recording_studio_user.auth.email_or_password_mismatch"), flash[:alert]
    assert_select "button", text: I18n.t("recording_studio_user.sessions.email_sign_in_code")

    post user_session_code_path, params: { user: { email: email } }
    assert_redirected_to verify_user_session_path
    code = RecordingStudioUser.otp_message(session[:otp_challenge_id]).fetch(:body)[/\d{6}/]
    accept_pending_live_terms!(user)
    post verify_user_session_path, params: { code: code }

    assert_redirected_to root_path
    follow_redirect!
    assert user.reload.confirmed?
    refute user.valid_password?(PASSWORD)
    assert session["warden.user.user.key"].present?
  end

  test "a password set after confirmation survives another confirmation" do
    email = unique_email("kept")
    user = RecordingStudioUser.create_user!(
      email: email,
      password: PASSWORD,
      password_confirmation: PASSWORD,
      first_name: "Kept",
      last_name: "Password",
      time_zone: "UTC",
      confirm: true
    )
    user.update!(password: "LaterPassword1!", password_confirmation: "LaterPassword1!")

    post "#{new_user_session_path}/otp", params: { user: { email: email } }
    code = RecordingStudioUser.otp_message(session[:otp_challenge_id]).fetch(:body)[/\d{6}/]
    post verify_user_session_path, params: { code: code }

    assert user.reload.valid_password?("LaterPassword1!")
    user.confirm
    assert user.reload.valid_password?("LaterPassword1!")
  end

  test "otp primary and password-less registration do not draw password signup" do
    @config.primary_login_type = :otp
    Rails.application.reload_routes!

    get "/users/sign_up/password"
    assert_response :not_found
    post "/users/sign_up/password", params: signup_params(unique_email("otp-primary"))
    assert_response :not_found
    refute Rails.application.routes.url_helpers.respond_to?(:user_registration_path)

    @config.primary_login_type = :email
    @config.registration_authentication_methods = %i[otp]
    Rails.application.reload_routes!

    get "/users/sign_up/password"
    assert_response :not_found
    post "/recording_studio_users/auth/sign_up/password", params: signup_params(unique_email("no-password"))
    assert_response :not_found
  end

  test "create_password refuses when password signup is not allowed" do
    email = unique_email("refused-create")

    @config.primary_login_type = :otp
    post user_registration_path, params: signup_params(email)

    assert_response :not_found
    assert_nil User.find_by(email: email)
  end

  test "password signup confirms by code when one-time sign-in is off" do
    email = unique_email("otp-off")
    @config.registration_authentication_methods = [:password]
    @config.otp_login_enabled = false
    @config.otp_registration_enabled = false
    @config.otp_enabled = false
    Rails.application.reload_routes!
    RecordingStudioUser::OtpNotifications.instance_variable_set(:@registered, false)
    RecordingStudioUser::EngineBoot.apply_otp_setup!(User)

    assert RecordingStudioUser::OtpNotifications.instance_variable_get(:@registered)
    assert Rails.application.routes.url_helpers.respond_to?(:user_session_code_path)

    post user_registration_path, params: signup_params(email)
    user = User.find_by!(email: email)

    assert_redirected_to verify_user_registration_path
    refute user.confirmed?

    submit_signup_code!
    assert_redirected_to root_path
    assert user.reload.confirmed?
    assert user.valid_password?(PASSWORD)
    assert session["warden.user.user.key"].present?
  ensure
    RecordingStudioUser::OtpNotifications.instance_variable_set(:@registered, false)
    RecordingStudioUser::OtpNotifications.register!
  end

  test "a failed confirmation code send leaves no account" do
    email = unique_email("orphan")

    assert_no_difference -> { User.count } do
      with_singleton_method(RecordingStudioUser::OtpSetup.singleton_class, :validate_schema!) do
        post user_registration_path, params: signup_params(email)
      rescue ArgumentError
        nil
      end
    end
    assert_nil User.find_by(email: email)

    assert_no_difference -> { User.count } do
      with_singleton_method(RecordingStudioUser.singleton_class, :request_otp!) do
        post user_registration_path, params: signup_params(email)
      rescue ArgumentError
        nil
      end
    end
    assert_nil User.find_by(email: email)
  end

  test "password sign-in code is absent when no code screen is routed" do
    email = unique_email("no-screen")
    @config.registration_authentication_methods = []
    @config.otp_login_enabled = false
    @config.otp_registration_enabled = false
    @config.otp_enabled = false
    Rails.application.reload_routes!

    refute Rails.application.routes.url_helpers.respond_to?(:user_session_code_path)
    refute RecordingStudioUser::Engine.routes.url_helpers.respond_to?(:sign_in_password_code_path)

    post user_session_path, params: { user: { email: email, password: PASSWORD } }
    assert_response :unprocessable_entity
    assert_select "button", text: I18n.t("recording_studio_user.sessions.email_sign_in_code"), count: 0

    post "/users/sign_in/password/code", params: { user: { email: email } }
    assert_response :not_found
    post "/recording_studio_users/auth/sign_in/password/code", params: { user: { email: email } }
    assert_response :not_found
  end

  test "password sign-in code uses the signup code screen when login codes are off" do
    email = unique_email("signup-screen")
    user = User.create!(
      email: email,
      password: PASSWORD,
      password_confirmation: PASSWORD,
      registered_with: "password"
    )
    disable_login_codes!

    post user_session_path, params: { user: { email: email, password: PASSWORD } }
    assert_response :unprocessable_entity
    assert_select "button", text: I18n.t("recording_studio_user.sessions.email_sign_in_code")

    post user_session_code_path, params: { user: { email: email } }
    assert_redirected_to verify_user_registration_path
    challenge = RecordingStudioUser::OtpChallenge.where(user: user).order(:created_at).last
    assert challenge.confirmation?

    code = RecordingStudioUser.otp_message(session[:otp_challenge_id]).fetch(:body)[/\d{6}/]
    accept_pending_live_terms!(user)
    post verify_user_registration_path, params: { code: code }
    assert_redirected_to root_path
    assert user.reload.confirmed?
  end

  test "confirmed and unknown addresses get the same notice when login codes are off" do
    confirmed = RecordingStudioUser.create_user!(
      email: unique_email("confirmed-code"),
      password: PASSWORD,
      password_confirmation: PASSWORD,
      first_name: "Confirmed",
      last_name: "Code",
      time_zone: "UTC",
      confirm: true
    )
    unknown = unique_email("unknown-code")
    disable_login_codes!
    notice = I18n.t("recording_studio_user.auth.eligible_code_sent")

    assert_no_difference -> { RecordingStudioUser::OtpChallenge.where(user: confirmed).count } do
      post user_session_code_path, params: { user: { email: confirmed.email } }
    end
    assert_redirected_to verify_user_registration_path
    assert_equal notice, flash[:notice]
    assert_nil session[:otp_purpose]

    post user_session_code_path, params: { user: { email: unknown } }
    assert_redirected_to verify_user_registration_path
    assert_equal notice, flash[:notice]
    assert_nil User.find_by(email: unknown)
    assert_nil session[:otp_purpose]
  end

  test "confirmation email is sent after the code row is persisted" do
    email = unique_email("after-commit")
    baseline = ActiveRecord::Base.connection.open_transactions
    calls = []
    watch_code_delivery(calls)

    post user_registration_path, params: signup_params(email)

    delivered = calls.last
    assert delivered
    assert_equal baseline, delivered.fetch(:depth)
    assert delivered.fetch(:persisted)
    assert RecordingStudioUser::OtpChallenge.exists?(delivered.fetch(:challenge_id))
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert User.find_by!(email: email)
  end

  test "staff create confirms and a public create does not" do
    staff = RecordingStudioUser::Directory.create_user!(
      email: unique_email("staff"),
      password: PASSWORD,
      password_confirmation: PASSWORD,
      first_name: "Staff",
      last_name: "Maker",
      time_zone: "UTC",
      confirm: true
    )
    public_user = RecordingStudioUser::Directory.create_user!(
      email: unique_email("public"),
      password: PASSWORD,
      password_confirmation: PASSWORD,
      first_name: "Public",
      last_name: "Signup",
      time_zone: "UTC",
      confirm: false
    )

    assert staff.confirmed?
    assert staff.valid_password?(PASSWORD)
    refute public_user.confirmed?
    assert public_user.valid_password?(PASSWORD)
  end

  test "a second confirmation code request inside the limit waits" do
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    email = unique_email("limited")

    post user_registration_path, params: signup_params(email)
    assert_redirected_to verify_user_registration_path

    owner = open_session
    owner.post user_session_code_path, params: { user: { email: email } }

    owner.assert_redirected_to verify_user_session_path
    assert_equal I18n.t("recording_studio_user.auth.wait_for_code"), owner.flash[:alert]
  ensure
    Rails.cache = previous
  end

  private

  def unique_email(label)
    "#{label}-#{SecureRandom.hex(4)}@example.com"
  end

  def signup_params(email)
    { user: { email: email, password: PASSWORD, password_confirmation: PASSWORD } }
  end

  def disable_login_codes!
    @config.registration_authentication_methods = [:password]
    @config.otp_login_enabled = false
    @config.otp_registration_enabled = false
    @config.otp_enabled = false
    Rails.application.reload_routes!
  end

  def watch_code_delivery(calls)
    job = RecordingStudioNotifications::DeliveryJob
    job.singleton_class.prepend(Module.new do
      define_method(:perform_now) do |*arguments, **keyword_arguments|
        challenge = RecordingStudioUser::OtpChallenge.order(:created_at).last
        calls << {
          depth: ActiveRecord::Base.connection.open_transactions,
          challenge_id: challenge&.id,
          persisted: challenge.present? && challenge.persisted?
        }
        super(*arguments, **keyword_arguments)
      end
    end)
  end

  def with_singleton_method(singleton, name)
    original = singleton.instance_method(name)
    singleton.define_method(name) { |*, **| raise ArgumentError, "code send failed" }
    yield
  ensure
    singleton.define_method(name, original)
  end

  def submit_signup_code!
    code = RecordingStudioUser.otp_message(session[:otp_challenge_id]).fetch(:body)[/\d{6}/]
    post verify_user_registration_path, params: { code: code }
  end
end
