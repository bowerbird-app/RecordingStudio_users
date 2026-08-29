# frozen_string_literal: true

require "test_helper"

class RegistrationPageTest < ActionDispatch::IntegrationTest
  test "sign up paints Flatpack email and password without confirmation by default" do
    get new_user_registration_path

    assert_response :success
    assert_select "html[data-theme='rounded']"
    assert_select "input#user_email[type='email']"
    assert_select "input#user_password[type='password']"
    assert_select "input#user_password_confirmation", count: 0
    assert_select "button[type='submit']", text: "Sign up"
    assert_select "body", text: /Avery|admin@admin.com/, count: 0
    assert_includes response.body, "text-center"
    assert_includes response.body, "Already have one?"

    assert_difference -> { User.count }, +1 do
      post user_registration_path, params: {
        user: {
          email: "no-confirm-#{SecureRandom.hex(4)}@example.com",
          password: "Password123!"
        }
      }
    end
  end

  test "sign up shows confirmation when the host turns the flag on" do
    original = RecordingStudioUser.config.require_password_confirmation
    RecordingStudioUser.config.require_password_confirmation = true

    get new_user_registration_path

    assert_response :success
    assert_select "html[data-theme='rounded']"
    assert_select "input#user_email[type='email']"
    assert_select "input#user_password[type='password']"
    assert_select "input#user_password_confirmation[type='password']"
    assert_select "button[type='submit']", text: "Sign up"
  ensure
    RecordingStudioUser.config.require_password_confirmation = original
  end
end
