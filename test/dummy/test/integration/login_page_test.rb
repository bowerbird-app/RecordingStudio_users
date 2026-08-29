# frozen_string_literal: true

require "test_helper"

class LoginPageTest < ActionDispatch::IntegrationTest
  test "login paints Welcome back without Card or Remember me" do
    get new_user_session_path

    assert_response :success
    assert_select "html[data-theme='rounded']"
    assert_select "h2", text: "Welcome back"
    assert_select "input[type='email'][name='user[email]']"
    assert_select "input[type='password'][name='user[password]']"
    assert_select "input[name='user[remember_me]']", count: 0
    assert_select "button[type='submit']", text: "Sign in"
    refute_includes response.body, "Remember me"
    refute_includes response.body, "FlatPack::Card"
    assert_includes response.body, "Don't have an account?"
    assert_includes response.body, "Continue with Google"
    assert_match(/\bOr\b/, response.body)
    assert_includes response.body, "Default: admin@admin.com / Password"
  end

  test "login title follows RecordingStudioUser.config.login_title" do
    original = RecordingStudioUser.config.login_title
    RecordingStudioUser.config.login_title = "Sign in to Acme"

    get new_user_session_path

    assert_response :success
    assert_select "h2", text: "Sign in to Acme"
  ensure
    RecordingStudioUser.config.login_title = original
  end
end
