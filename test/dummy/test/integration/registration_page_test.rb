# frozen_string_literal: true

require "test_helper"

class RegistrationPageTest < ActionDispatch::IntegrationTest
  test "sign up paints Flatpack email, password, and confirmation fields" do
    get new_user_registration_path

    assert_response :success
    assert_select "html[data-theme='rounded']"
    assert_select "input#user_email[type='email']"
    assert_select "input#user_password[type='password']"
    assert_select "input#user_password_confirmation[type='password']"
    assert_select "button[type='submit']", text: "Sign up"
    assert_select "body", text: /Avery|admin@admin.com/, count: 0
    assert_includes response.body, "text-center"
    assert_includes response.body, "Already have one?"
    refute_includes response.body, "fixed inset-0"
    refute_includes response.body, "Email OTP"
    %w[Google Microsoft Apple LinkedIn Instagram].each do |label|
      assert_select "form[method='post'] button[type='submit']", text: "Continue with #{label}"
    end
  end

  test "sign up omits confirmation when the host turns the flag off" do
    original = RecordingStudioUser.config.require_password_confirmation
    RecordingStudioUser.config.require_password_confirmation = false

    get new_user_registration_path

    assert_response :success
    assert_select "html[data-theme='rounded']"
    assert_select "input#user_email[type='email']"
    assert_select "input#user_password[type='password']"
    assert_select "input#user_password_confirmation", count: 0
    assert_select "button[type='submit']", text: "Sign up"

    assert_difference -> { User.count }, +1 do
      post user_registration_path, params: {
        user: {
          email: "no-confirm-#{SecureRandom.hex(4)}@example.com",
          password: "Password123!"
        }
      }
    end
  ensure
    RecordingStudioUser.config.require_password_confirmation = original
  end
end
