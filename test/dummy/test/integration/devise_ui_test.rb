# frozen_string_literal: true

require "test_helper"

class DeviseUiTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      first_name: "Taylor",
      last_name: "Member",
      email: "taylor@example.com",
      time_zone: "UTC",
      password: "Password123!"
    )
  end

  test "sign in uses the gem-owned FlatPack view" do
    get new_user_session_path

    assert_response :success
    assert_select "input[name='user[email]'][autocomplete='email']"
    assert_select "input[name='user[password]'][autocomplete='current-password']"
    assert_select ".flat-pack-input", minimum: 2
    assert_includes response.body, "Forgot your password?"
  end

  test "password reset request renders and submits" do
    get new_user_password_path

    assert_response :success
    assert_select "input[name='user[email]']"

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post user_password_path, params: { user: { email: @user.email } }
    end
    assert_redirected_to new_user_session_path
  end
end
