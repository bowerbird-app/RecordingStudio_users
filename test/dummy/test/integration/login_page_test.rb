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
    refute_includes response.body, "fixed inset-0"
    refute_includes response.body, "place-content-center"
    refute_includes response.body, "justify: :center"
    refute_includes response.body, "max: :sm"
    source = File.read(Rails.root.join("app/views/devise/sessions/new.html.erb"))
    refute_includes source, "FlatPack::Card::Component"
    refute_includes source, "remember_me"
    refute_includes source, "Badge::Component"
    assert_includes response.body, "min-h-dvh"
    assert_includes response.body, "max-w-sm"
    assert_includes response.body, "Don't have an account?"
    assert_includes response.body, "text-center"
    assert_match(/\bOr\b/, response.body)
    refute_includes response.body, "Default: admin@admin.com / Password"

    %w[Google Microsoft Apple LinkedIn Instagram].each do |label|
      assert_select "form[method='post'] button[type='submit']", text: "Continue with #{label}"
    end
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
