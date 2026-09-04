# frozen_string_literal: true

require "test_helper"

class LoginPageTest < ActionDispatch::IntegrationTest
  AUTH_SESSIONS_VIEW = RecordingStudioUser::Engine.root.join(
    "app/views/recording_studio_user/auth/sessions/new.html.erb"
  ).freeze

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
    refute_includes response.body, "Email OTP"
    refute_includes response.body, "Continue with password"
    refute_includes response.body, "/sign_in/otp"
    refute_includes response.body, "fixed inset-0"
    refute_includes response.body, "place-content-center"
    refute_includes response.body, "Default: admin@admin.com / Password"
    source = File.read(AUTH_SESSIONS_VIEW)
    shell = File.read(
      RecordingStudioUser::Engine.root.join("app/views/recording_studio_user/auth/_shell.html.erb")
    )
    refute_includes source, "FlatPack::Card::Component"
    refute_includes source, "otp_session_otp_path"
    assert_includes source, 'layout: "recording_studio_user/auth/shell"'
    refute_includes shell, "min-h-dvh"
    assert_includes shell, "max-w-sm"
    assert_equal 1, response.body.scan("min-h-dvh").length
    assert_includes response.body, "max-w-sm"
    assert_includes response.body, "Don't have an account?"
    assert_includes response.body, "text-center"
    assert_includes response.body, 'href="/users/sign_up"'
    refute_includes response.body, 'href="/recording_studio_users/auth/sign_up"'
    assert_match(/\bOr\b/, response.body)

    %w[Google Microsoft Apple LinkedIn Instagram].each do |label|
      assert_select "form[method='post'] button[type='submit']", text: "Continue with #{label}"
    end
  end

  test "password sign in path renders the same primary form" do
    get "#{new_user_session_path}/password"

    assert_response :success
    assert_select "input[type='email'][name='user[email]']"
    assert_select "input[type='password'][name='user[password]']"
    assert_select "button[type='submit']", text: "Sign in"
    refute_includes response.body, "Email OTP"
  end

  test "direct OTP sign in page renders email form without primary chooser" do
    get "#{new_user_session_path}/otp"

    assert_response :success
    assert_select "input[name='user[email]']"
    assert_select "button[type='submit']", text: "Send code"
    assert_equal 1, response.body.scan("min-h-dvh").length
    assert_includes response.body, "max-w-sm"
    refute_includes response.body, "Continue with password"
  end

  test "password login stays available when OTP is turned off" do
    original = RecordingStudioUser.config.otp_enabled
    RecordingStudioUser.config.otp_enabled = false

    get new_user_session_path
    assert_response :success
    assert_select "h2", text: "Welcome back"
    assert_select "button[type='submit']", text: "Sign in"

    get "#{new_user_session_path}/otp"
    assert_response :not_found

    get new_user_registration_path
    assert_response :success
    assert_select "button[type='submit']", text: "Sign up"

    get "#{new_user_registration_path}/otp"
    assert_response :not_found
  ensure
    RecordingStudioUser.config.otp_enabled = original
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

  test "dummy OmniAuth follows credentials and never enables OmniAuth test mode in the app" do
    source = File.read(Rails.root.join("config/initializers/recording_studio_user.rb"))
    initializer_paths = Dir[Rails.root.join("config/initializers/*.rb")]

    refute_includes source, "ENV["
    refute_includes source, "OMNIAUTH_TEST_MODE"
    refute_includes source, "OmniAuth.config.test_mode"
    initializer_paths.each do |path|
      contents = File.read(path)
      refute_includes contents, "OMNIAUTH_TEST_MODE"
      refute_includes contents, "OmniAuth.config.test_mode"
    end
    assert_includes source, "omniauth:"
  end
end
