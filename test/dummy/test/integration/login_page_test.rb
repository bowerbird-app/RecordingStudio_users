# frozen_string_literal: true

require "test_helper"

class LoginPageTest < ActionDispatch::IntegrationTest
  test "sign in offers password, OTP, and provider forms" do
    get new_user_session_path

    assert_response :success
    assert_select "h2", text: "Sign in"
    assert_select "body", text: /Password/
    assert_select "body", text: /Email OTP/

    %w[Google Microsoft Apple LinkedIn Instagram].each do |label|
      assert_select "form[method='post'] button[type='submit']", text: "Continue with #{label}"
    end
  end

  test "password sign in paints Flatpack fields and provider forms" do
    get "#{new_user_session_path}/password"

    assert_response :success
    assert_select "input[type='email'][name='user[email]']"
    assert_select "input[type='password'][name='user[password]']"
    assert_select "button[type='submit']", text: "Sign in"

    %w[Google Microsoft Apple LinkedIn Instagram].each do |label|
      assert_select "form[method='post'] button[type='submit']", text: "Continue with #{label}"
    end
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
