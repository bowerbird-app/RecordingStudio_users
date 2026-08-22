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
  end
end
