# frozen_string_literal: true

require "test_helper"

class PasswordResetPageTest < ActionDispatch::IntegrationTest
  PASSWORD_NEW_VIEW = RecordingStudioUser::Engine.root.join(
    "app/views/recording_studio_user/auth/passwords/new.html.erb"
  ).freeze
  PASSWORD_EDIT_VIEW = RecordingStudioUser::Engine.root.join(
    "app/views/recording_studio_user/auth/passwords/edit.html.erb"
  ).freeze

  test "forgot password matches the shared auth chrome" do
    get new_user_password_path

    assert_response :success
    assert_select "html[data-theme='rounded']"
    assert_select "h2", text: "Forgot your password?"
    assert_select "input[type='email'][name='user[email]'][placeholder='you@company.com']"
    assert_select "label", text: "Email", count: 0
    assert_select "button[type='submit']", text: "Send reset link"
    assert_select "a[href='#{new_user_session_path}']", text: "Back to sign in"
    assert_equal 1, response.body.scan("min-h-dvh").length
    assert_includes response.body, "max-w-sm"
    refute_includes File.read(PASSWORD_NEW_VIEW), "FlatPack::Card::Component"
  end

  test "reset link renders the Flatpack new password form" do
    get edit_user_password_path(reset_password_token: "reset-token")

    assert_response :success
    assert_select "html[data-theme='rounded']"
    assert_select "h2", text: "Choose a new password"
    assert_select "input[type='hidden'][name='user[reset_password_token]'][value='reset-token']"
    assert_select "input[type='password'][name='user[password]']"
    assert_select "input[type='password'][name='user[password_confirmation]']"
    assert_select "button[type='submit']", text: "Save password"
    assert_equal 1, response.body.scan("min-h-dvh").length
    refute_includes File.read(PASSWORD_EDIT_VIEW), "FlatPack::Card::Component"
  end

  test "a valid reset token saves the new password" do
    user = User.new(
      email: "password-reset-page@example.com",
      password: "CurrentPassword123!",
      password_confirmation: "CurrentPassword123!"
    )
    user.registered_with = "password" if user.respond_to?(:registered_with=)
    user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
    user.save!
    raw_token, encrypted_token = Devise.token_generator.generate(User, :reset_password_token)
    user.update_columns(reset_password_token: encrypted_token, reset_password_sent_at: Time.current)

    put user_password_path, params: {
      user: {
        reset_password_token: raw_token,
        password: "BrandNewPassword123!",
        password_confirmation: "BrandNewPassword123!"
      }
    }

    assert_redirected_to root_path
    assert user.reload.valid_password?("BrandNewPassword123!")
  end

  test "resend confirmation matches the shared auth chrome" do
    get new_user_confirmation_path

    assert_response :success
    assert_select "html[data-theme='rounded']"
    assert_select "h2", text: "Resend confirmation"
    assert_select "input[type='email'][name='user[email]'][placeholder='you@company.com']"
    assert_select "button[type='submit']", text: "Resend confirmation"
    assert_equal 1, response.body.scan("min-h-dvh").length
    assert_includes response.body, "max-w-sm"
  end
end
