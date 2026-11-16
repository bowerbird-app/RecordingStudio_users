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
    @originals.each { |setting, value| @config.public_send("#{setting}=", value) }
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

    submit_signup_code!
    assert_redirected_to root_path
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
      time_zone: "UTC"
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

  test "staff create confirms and a public create does not" do
    staff = RecordingStudioUser::Directory.create_user_without_test_default!(
      email: unique_email("staff"),
      password: PASSWORD,
      password_confirmation: PASSWORD,
      first_name: "Staff",
      last_name: "Maker",
      time_zone: "UTC",
      confirm: true
    )
    public_user = RecordingStudioUser::Directory.create_user_without_test_default!(
      email: unique_email("public"),
      password: PASSWORD,
      password_confirmation: PASSWORD,
      first_name: "Public",
      last_name: "Signup",
      time_zone: "UTC"
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

  def submit_signup_code!
    code = RecordingStudioUser.otp_message(session[:otp_challenge_id]).fetch(:body)[/\d{6}/]
    post verify_user_registration_path, params: { code: code }
  end
end
