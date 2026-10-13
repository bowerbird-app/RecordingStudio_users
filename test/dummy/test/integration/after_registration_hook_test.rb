# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AfterRegistrationHookTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @calls = []
    @original_hooks = RecordingStudioUser.config.after_registration_hooks.dup
    RecordingStudioUser.config.after_registration_hooks.clear
    RecordingStudioUser.config.after_registration ->(user:, method:) {
      @calls << { user_id: user.id, email: user.email, method: method }
    }

    OmniAuth.config.test_mode = true
    clear_omniauth_mocks!
    @original_create_account = RecordingStudioUser.config.omniauth_create_account
    RecordingStudioUser.config.omniauth_create_account = true
    ActionMailer::Base.deliveries.clear
    Rails.cache.clear
  end

  teardown do
    RecordingStudioUser.config.after_registration_hooks.clear
    @original_hooks.each { |hook| RecordingStudioUser.config.after_registration_hooks << hook }
    clear_omniauth_mocks!
    RecordingStudioUser.config.omniauth_create_account = @original_create_account
  end

  test "password signup fires after_registration with method password" do
    email = "after-reg-pw-#{SecureRandom.hex(4)}@example.com"

    post user_registration_path, params: {
      user: { email: email, password: "Password123!", password_confirmation: "Password123!" }
    }

    user = User.find_by!(email: email)
    assert_equal [{ user_id: user.id, email: email, method: :password }], @calls
  end

  test "oauth new user fires after_registration with method oauth" do
    email = "after-reg-oauth-#{SecureRandom.hex(4)}@example.com"
    mock_provider_auth!(
      :google_oauth2,
      uid: "after-reg-oauth-#{SecureRandom.hex(4)}",
      email: email,
      first_name: "New",
      last_name: "OAuth"
    )

    assert_difference -> { User.count }, +1 do
      get user_google_oauth2_omniauth_callback_path
    end

    user = User.find_by!(email: email)
    assert_equal [{ user_id: user.id, email: email, method: :oauth }], @calls
  end

  test "otp registration fires after_registration with method otp" do
    email = "after-reg-otp-#{SecureRandom.hex(4)}@example.com"
    post "#{new_user_registration_path}/otp", params: { user: { email: email } }
    user = User.find_by!(email: email)
    challenge = RecordingStudioUser::OtpChallenge.find_by!(user_id: user.id, purpose: "registration")
    code = challenge.decrypt_delivery_code!
    @calls.clear

    post verify_user_registration_path, params: { code: code }

    user.reload
    assert user.confirmed?
    assert_equal [{ user_id: user.id, email: email, method: :otp }], @calls
  end

  test "password login does not fire after_registration" do
    email = "after-reg-login-#{SecureRandom.hex(4)}@example.com"
    user = RecordingStudioUser.create_user!(
      email: email,
      password: "Password123!",
      first_name: "Log",
      last_name: "In",
      time_zone: "UTC"
    )
    accept_pending_live_terms!(user)
    @calls.clear

    post user_session_path, params: { user: { email: email, password: "Password123!" } }

    assert_redirected_to root_path
    assert_empty @calls
  end

  test "oauth link to existing user does not fire after_registration" do
    email = "after-reg-link-#{SecureRandom.hex(4)}@example.com"
    existing = RecordingStudioUser.create_user!(
      email: email,
      password: "Password123!",
      first_name: "Existing",
      last_name: "User",
      time_zone: "UTC"
    )
    @calls.clear
    mock_provider_auth!(
      :google_oauth2,
      uid: "after-reg-link-#{SecureRandom.hex(4)}",
      email: email
    )

    assert_no_difference -> { User.count } do
      assert_difference -> { RecordingStudioUser::Identity.count }, +1 do
        get user_google_oauth2_omniauth_callback_path
      end
    end

    assert existing.identities.exists?(provider: "google_oauth2")
    assert_empty @calls
  end

  test "oauth login for existing identity does not fire after_registration" do
    email = "after-reg-oauth-login-#{SecureRandom.hex(4)}@example.com"
    user = RecordingStudioUser.create_user!(
      email: email,
      password: "Password123!",
      first_name: "Return",
      last_name: "Visit",
      time_zone: "UTC"
    )
    uid = "after-reg-return-#{SecureRandom.hex(4)}"
    user.identities.create!(provider: "google_oauth2", uid: uid, email: email)
    @calls.clear
    mock_provider_auth!(:google_oauth2, uid: uid, email: email)

    assert_no_difference -> { User.count } do
      get user_google_oauth2_omniauth_callback_path
    end

    assert_empty @calls
  end

  test "password signup that fails validation does not fire after_registration" do
    assert_no_difference -> { User.count } do
      post user_registration_path, params: {
        user: { email: "bad", password: "short", password_confirmation: "mismatch" }
      }
    end

    assert_empty @calls
  end

  test "hook error is reported and does not break password signup" do
    RecordingStudioUser.config.after_registration_hooks.clear
    RecordingStudioUser.config.after_registration ->(user:, method:) {
      raise StandardError, "host hook exploded"
    }

    email = "after-reg-error-#{SecureRandom.hex(4)}@example.com"

    assert_error_reported(StandardError) do
      post user_registration_path, params: {
        user: { email: email, password: "Password123!", password_confirmation: "Password123!" }
      }
    end

    assert User.exists?(email: email)
  end

  private

  def clear_omniauth_mocks!
    %i[google_oauth2 microsoft_graph apple linkedin instagram].each do |provider|
      OmniAuth.config.mock_auth[provider] = nil
    end
  end

  def mock_provider_auth!(provider, uid:, email:, first_name: "OAuth", last_name: "User")
    OmniAuth.config.mock_auth[provider] = OmniAuth::AuthHash.new(
      provider: provider.to_s,
      uid: uid,
      info: {
        email: email,
        name: "#{first_name} #{last_name}",
        first_name: first_name,
        last_name: last_name
      }
    )
  end
end
