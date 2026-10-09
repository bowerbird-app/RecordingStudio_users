# frozen_string_literal: true

require "test_helper"

# OTP routes are drawn only when the matching flags are on at route-draw time.
# Dummy boots with OTP on; these tests flip config and reload routes.
class OtpRoutesDisabledTest < ActionDispatch::IntegrationTest
  REGISTRATION_OTP_PATHS = [
    [:get, "/users/sign_up/otp"],
    [:post, "/users/sign_up/otp"],
    [:get, "/users/sign_up/verify"],
    [:post, "/users/sign_up/verify"],
    [:post, "/users/sign_up/resend"],
    [:get, "/recording_studio_users/auth/sign_up/otp"],
    [:post, "/recording_studio_users/auth/sign_up/otp"],
    [:get, "/recording_studio_users/auth/sign_up/verify"],
    [:post, "/recording_studio_users/auth/sign_up/verify"],
    [:post, "/recording_studio_users/auth/sign_up/resend"]
  ].freeze

  LOGIN_OTP_PATHS = [
    [:get, "/users/sign_in/otp"],
    [:post, "/users/sign_in/otp"],
    [:get, "/users/sign_in/verify"],
    [:post, "/users/sign_in/verify"],
    [:post, "/users/sign_in/resend"],
    [:get, "/recording_studio_users/auth/sign_in/otp"],
    [:post, "/recording_studio_users/auth/sign_in/otp"],
    [:get, "/recording_studio_users/auth/sign_in/verify"],
    [:post, "/recording_studio_users/auth/sign_in/verify"],
    [:post, "/recording_studio_users/auth/sign_in/resend"]
  ].freeze

  setup do
    @config = RecordingStudioUser.config
    @originals = {
      otp_enabled: @config.otp_enabled,
      otp_registration_enabled: @config.otp_registration_enabled,
      otp_login_enabled: @config.otp_login_enabled,
      primary_login_type: @config.primary_login_type,
      registration_authentication_methods:
        @config.instance_variable_get(:@registration_authentication_methods)
    }
  end

  teardown do
    restore_otp_config!
    reload_auth_routes!
  end

  test "otp off removes every registration and login OTP path" do
    disable_otp!
    reload_auth_routes!

    assert_otp_paths_missing(REGISTRATION_OTP_PATHS + LOGIN_OTP_PATHS)
    refute named_route?(:verify_user_registration_path)
    refute named_route?(:verify_user_session_path)
    refute named_route?(:resend_user_registration_path)
    refute named_route?(:resend_user_session_path)
    refute engine_named_route?(:sign_up_otp_path)
    refute engine_named_route?(:sign_in_otp_path)
    refute engine_named_route?(:otp_code_path)

    get new_user_session_path
    assert_response :success
    get new_user_registration_path
    assert_response :success
  end

  test "otp registration off removes only registration OTP paths" do
    disable_otp_registration!
    reload_auth_routes!

    assert_otp_paths_missing(REGISTRATION_OTP_PATHS)
    assert_otp_paths_routed(LOGIN_OTP_PATHS)
    refute named_route?(:verify_user_registration_path)
    assert named_route?(:verify_user_session_path)
  end

  test "otp login off removes only login OTP paths" do
    disable_otp_login!
    reload_auth_routes!

    assert_otp_paths_missing(LOGIN_OTP_PATHS)
    assert_otp_paths_routed(REGISTRATION_OTP_PATHS)
    refute named_route?(:verify_user_session_path)
    assert named_route?(:verify_user_registration_path)
  end

  test "password email screens never link to OTP paths" do
    disable_otp!
    reload_auth_routes!

    get new_user_session_path
    assert_response :success
    refute_includes response.body, "/sign_in/otp"
    refute_includes response.body, "/sign_in/verify"

    get new_user_registration_path
    assert_response :success
    refute_includes response.body, "/sign_up/otp"
    refute_includes response.body, "/sign_up/verify"
  end

  private

  def disable_otp!
    @config.primary_login_type = :email
    @config.otp_enabled = false
  end

  def disable_otp_registration!
    @config.primary_login_type = :email
    @config.otp_registration_enabled = false
  end

  def disable_otp_login!
    @config.primary_login_type = :email
    @config.instance_variable_set(:@registration_authentication_methods, %i[password])
    @config.instance_variable_set(:@otp_login_enabled, false)
  end

  def restore_otp_config!
    @config.instance_variable_set(
      :@registration_authentication_methods,
      @originals[:registration_authentication_methods]
    )
    @config.instance_variable_set(:@otp_login_enabled, @originals[:otp_login_enabled])
    @config.otp_registration_enabled = @originals[:otp_registration_enabled]
    @config.otp_enabled = @originals[:otp_enabled]
    @config.primary_login_type = @originals[:primary_login_type]
  end

  def reload_auth_routes!
    Rails.application.reload_routes!
  end

  def assert_otp_paths_missing(paths)
    paths.each do |http_method, path|
      public_send(http_method, path)
      assert_response :not_found, "#{http_method.upcase} #{path} should be unreachable"
    end
  end

  def assert_otp_paths_routed(paths)
    paths.each do |http_method, path|
      assert recognize_route?(http_method, path),
             "#{http_method.upcase} #{path} should still be routed"
    end
  end

  def recognize_route?(http_method, path)
    Rails.application.routes.recognize_path(path, method: http_method)
    true
  rescue ActionController::RoutingError
    false
  end

  def named_route?(name)
    Rails.application.routes.url_helpers.respond_to?(name)
  end

  def engine_named_route?(name)
    RecordingStudioUser::Engine.routes.url_helpers.respond_to?(name)
  end
end
