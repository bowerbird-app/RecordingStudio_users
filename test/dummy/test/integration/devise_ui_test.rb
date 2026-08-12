# frozen_string_literal: true

require "test_helper"

class DeviseUiTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_or_initialize_by(email: "taylor@example.com")
    @user.assign_attributes(
      first_name: "Taylor",
      last_name: "Member",
      time_zone: "UTC",
      password: "Password123!"
    )
    @user.save!
  end

  test "sign in uses the gem-owned FlatPack view" do
    get new_user_session_path

    assert_response :success
    assert_select "input[name='user[email]'][autocomplete='email']"
    assert_select "input[name='user[password]'][autocomplete='current-password']"
    assert_select ".flat-pack-input", minimum: 2
    assert_includes response.body, "Forgot your password?"
    assert_select "a", text: "My profile", count: 0
    assert_select "a", text: "Admin", count: 0
    assert_select "a", text: "Sign out", count: 0
  end

  test "password reset request renders and submits" do
    get new_user_password_path

    assert_response :success
    assert_select "input[name='user[email]']"
    assert_select "a", text: "My profile", count: 0
    assert_select "a", text: "Admin", count: 0
    assert_select "a", text: "Sign out", count: 0

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post user_password_path, params: { user: { email: @user.email } }
    end
    assert_redirected_to new_user_session_path
  end

  test "password reset edit and update flow renders and changes credentials" do
    raw_token = @user.send_reset_password_instructions

    get edit_user_password_path(reset_password_token: raw_token)

    assert_response :success
    assert_select "input[name='user[password]'][autocomplete='new-password']"
    assert_select "input[name='user[password_confirmation]'][autocomplete='new-password']"

    put user_password_path, params: {
      user: {
        reset_password_token: raw_token,
        password: "NewPassword123!",
        password_confirmation: "NewPassword123!"
      }
    }

    assert_redirected_to root_path
    @user.reload
    assert @user.valid_password?("NewPassword123!")
    refute @user.valid_password?("Password123!")
  end
end
