# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AccountEnumerationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "password sign-in uses one mismatch notice for unknown wrong and OTP-only emails" do
    password_email = "enum-password-#{SecureRandom.hex(4)}@example.com"
    RecordingStudioUser.create_user!(
      email: password_email,
      password: "Password123!",
      first_name: "Enum",
      last_name: "Password",
      time_zone: "UTC"
    )
    otp_email = "enum-otp-#{SecureRandom.hex(4)}@example.com"
    confirm_otp_user!(otp_email)
    sign_out :user
    unknown = "enum-unknown-#{SecureRandom.hex(4)}@example.com"
    mismatch = I18n.t("recording_studio_user.auth.email_or_password_mismatch")

    {
      unknown => "Password123!",
      password_email => "not-the-password",
      otp_email => "Password123!"
    }.each do |email, password|
      post "/users/sign_in/password", params: { user: { email: email, password: password } }

      assert_response :unprocessable_entity, email
      assert_equal mismatch, flash[:alert], email
      assert_includes response.body, mismatch
      refute_match(/email codes|already has an account/i, response.body)
    end
  end

  test "password reset uses one send-instructions notice for unknown password and OTP-only emails" do
    password_email = "enum-reset-#{SecureRandom.hex(4)}@example.com"
    RecordingStudioUser.create_user!(
      email: password_email,
      password: "Password123!",
      first_name: "Enum",
      last_name: "Reset",
      time_zone: "UTC"
    )
    otp_email = "enum-reset-otp-#{SecureRandom.hex(4)}@example.com"
    confirm_otp_user!(otp_email)
    sign_out :user
    unknown = "enum-reset-unknown-#{SecureRandom.hex(4)}@example.com"
    notice = I18n.t("devise.passwords.send_instructions")

    [unknown, password_email, otp_email].each do |email|
      ActionMailer::Base.deliveries.clear
      post user_password_path, params: { user: { email: email } }

      assert_redirected_to new_user_session_path, email
      assert_equal notice, flash[:notice], email
      refute_match(/email codes/i, flash[:notice].to_s)
    end

    ActionMailer::Base.deliveries.clear
    post user_password_path, params: { user: { email: password_email } }
    assert_equal 1, ActionMailer::Base.deliveries.size

    ActionMailer::Base.deliveries.clear
    post user_password_path, params: { user: { email: unknown } }
    assert_empty ActionMailer::Base.deliveries

    ActionMailer::Base.deliveries.clear
    post user_password_path, params: { user: { email: otp_email } }
    assert_empty ActionMailer::Base.deliveries
  end

  test "password sign-up does not confirm that an existing email is taken" do
    email = "enum-signup-#{SecureRandom.hex(4)}@example.com"
    RecordingStudioUser.create_user!(
      email: email,
      password: "Password123!",
      first_name: "Enum",
      last_name: "Signup",
      time_zone: "UTC"
    )
    generic = I18n.t("recording_studio_user.auth.signup_did_not_save")

    assert_no_difference -> { User.count } do
      post user_registration_path, params: {
        user: { email: email, password: "Password123!", password_confirmation: "Password123!" }
      }
    end

    assert_response :unprocessable_entity
    assert_equal generic, flash[:alert]
    refute_match(/already has an account|has already been taken|email codes/i, response.body)
  end

  private

  def confirm_otp_user!(email)
    post "#{new_user_registration_path}/otp", params: { user: { email: email } }
    user = User.find_by!(email: email)
    challenge = RecordingStudioUser::OtpChallenge.where(
      user: user, purpose: "registration", consumed_at: nil, revoked_at: nil
    ).order(created_at: :desc).first!
    post "#{verify_user_registration_path}", params: { code: challenge.decrypt_delivery_code! }
    user.reload
  end
end
