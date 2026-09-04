# frozen_string_literal: true

require "test_helper"

class RegistrationPageTest < ActionDispatch::IntegrationTest
  AUTH_REGISTRATIONS_VIEW = RecordingStudioUser::Engine.root.join(
    "app/views/recording_studio_user/auth/registrations/new.html.erb"
  ).freeze
  AUTH_PASSWORD_VIEW = RecordingStudioUser::Engine.root.join(
    "app/views/recording_studio_user/auth/registrations/password.html.erb"
  ).freeze

  test "sign up paints Flatpack email only without confirmation by default" do
    get new_user_registration_path

    assert_response :success
    assert_select "html[data-theme='rounded']"
    assert_select "input#user_email[type='email']"
    assert_select "input#user_password[type='password']", count: 0
    assert_select "input#user_password_confirmation", count: 0
    assert_select "button[type='submit']", text: "Continue with email"
    assert_select "body", text: /Avery|admin@admin.com/, count: 0
    refute_includes response.body, "Continue with email OTP"
    refute_includes response.body, "Continue with password"
    refute_includes response.body, "/sign_up/otp"
    refute_includes response.body, "fixed inset-0"
    source = File.read(AUTH_REGISTRATIONS_VIEW)
    shell = File.read(
      RecordingStudioUser::Engine.root.join("app/views/recording_studio_user/auth/_shell.html.erb")
    )
    refute_includes source, "FlatPack::Card::Component"
    refute_includes source, "otp_registration_otp_path"
    assert_includes source, 'layout: "recording_studio_user/auth/shell"'
    assert_includes shell, "min-h-dvh"
    assert_includes shell, "max-w-sm"
    assert_includes response.body, "min-h-dvh"
    assert_includes response.body, "max-w-sm"
    assert_includes response.body, "text-center"
    assert_includes response.body, "Already have one?"
    assert_includes response.body, 'href="/users/sign_in"'
    refute_includes response.body, 'href="/recording_studio_users/auth/sign_in"'
    assert_match(/\bOr\b/, response.body)

    %w[Google Microsoft Apple LinkedIn Instagram].each do |label|
      assert_select "form[method='post'] button[type='submit']", text: "Continue with #{label}"
    end

    email = "no-confirm-#{SecureRandom.hex(4)}@example.com"
    post new_user_registration_path, params: { user: { email: email } }
    assert_redirected_to "#{new_user_registration_path}/password"
    follow_redirect!
    assert_select "input#user_password[type='password']"
    assert_select "button[type='submit']", text: "Sign up"

    assert_difference -> { User.count }, +1 do
      post user_registration_path, params: {
        user: {
          email: email,
          password: "Password123!"
        }
      }
    end
  end

  test "continue with email primary opens password screen" do
    email = "reg-step-#{SecureRandom.hex(4)}@example.com"
    post new_user_registration_path, params: { user: { email: email } }

    assert_redirected_to "#{new_user_registration_path}/password"
    follow_redirect!

    assert_response :success
    assert_select "input[type='hidden'][name='user[email]'][value='#{email}']"
    assert_select "input#user_password[type='password']"
    assert_select "input#user_email[type='email']", count: 0
    assert_select "button[type='submit']", text: "Sign up"
    refute_includes response.body, "Already have one?"
    refute_includes response.body, "Continue with Google"
    password_source = File.read(AUTH_PASSWORD_VIEW)
    refute_includes password_source, "FlatPack::Card::Component"
    assert_includes password_source, 'layout: "recording_studio_user/auth/shell"'
  end

  test "password sign up path without email sends you back to start" do
    get "#{new_user_registration_path}/password"

    assert_redirected_to new_user_registration_path
  end

  test "direct OTP sign up page renders email form without primary chooser" do
    get "#{new_user_registration_path}/otp"

    assert_response :success
    assert_select "input[name='user[email]']"
    assert_select "button[type='submit']", text: "Send code"
    assert_includes response.body, "min-h-dvh"
    assert_includes response.body, "max-w-sm"
    refute_includes response.body, "Continue with password"
  end

  test "primary otp continue issues a registration code" do
    original = RecordingStudioUser.config.primary_login_type
    RecordingStudioUser.config.primary_login_type = :otp
    email = "primary-otp-reg-#{SecureRandom.hex(4)}@example.com"

    assert_difference -> { User.count }, +1 do
      post new_user_registration_path, params: { user: { email: email } }
    end

    assert_redirected_to verify_user_registration_path
    user = User.find_by!(email: email)
    assert user.registered_with_otp?
    refute user.confirmed?
  ensure
    RecordingStudioUser.config.primary_login_type = original
  end

  test "sign up shows confirmation when the host turns the flag on" do
    original = RecordingStudioUser.config.require_password_confirmation
    RecordingStudioUser.config.require_password_confirmation = true
    email = "confirm-flag-#{SecureRandom.hex(4)}@example.com"

    post new_user_registration_path, params: { user: { email: email } }
    follow_redirect!

    assert_response :success
    assert_select "html[data-theme='rounded']"
    assert_select "input#user_password[type='password']"
    assert_select "input#user_password_confirmation[type='password']"
    assert_select "button[type='submit']", text: "Sign up"
  ensure
    RecordingStudioUser.config.require_password_confirmation = original
  end
end
