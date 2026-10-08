# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class RegistrationCompletedEventTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  EVENT = RecordingStudioUser::RegistrationCompleted::EVENT
  OTP_EVENT = "otp.registration_completed.recording_studio_user"

  setup do
    @events = []
    @otp_events = []
    @subscriber = ActiveSupport::Notifications.subscribe(EVENT) do |_n, _s, _f, _i, payload|
      user = User.find_by(id: payload[:user_id])
      @events << payload.merge(user_found: user.present?)
    end
    @otp_subscriber = ActiveSupport::Notifications.subscribe(OTP_EVENT) do |_n, _s, _f, _i, payload|
      @otp_events << payload
    end
    OmniAuth.config.test_mode = true
    clear_omniauth_mocks!
    @original_create_account = RecordingStudioUser.config.omniauth_create_account
    RecordingStudioUser.config.omniauth_create_account = true
    ActionMailer::Base.deliveries.clear
    Rails.cache.clear
  end

  teardown do
    ActiveSupport::Notifications.unsubscribe(@subscriber)
    ActiveSupport::Notifications.unsubscribe(@otp_subscriber)
    clear_omniauth_mocks!
    RecordingStudioUser.config.omniauth_create_account = @original_create_account
  end

  test "password signup emits registration.completed with method password" do
    email = "reg-event-pw-#{SecureRandom.hex(4)}@example.com"

    post user_registration_path, params: {
      user: { email: email, password: "Password123!", password_confirmation: "Password123!" }
    }

    user = User.find_by!(email: email)
    assert_equal [{ user_id: user.id, method: :password, user_found: true }], @events
  end

  test "password signup that fails validation does not emit" do
    assert_no_difference -> { User.count } do
      post user_registration_path, params: {
        user: { email: "bad", password: "short", password_confirmation: "mismatch" }
      }
    end

    assert_empty @events
  end

  test "password login does not emit" do
    email = "reg-event-login-#{SecureRandom.hex(4)}@example.com"
    RecordingStudioUser.create_user!(
      email: email,
      password: "Password123!",
      first_name: "Log",
      last_name: "In",
      time_zone: "UTC"
    )
    @events.clear

    post user_session_path, params: { user: { email: email, password: "Password123!" } }

    assert_redirected_to root_path
    assert_empty @events
  end

  test "oauth new user creation emits with method oauth" do
    email = "reg-event-oauth-#{SecureRandom.hex(4)}@example.com"
    mock_provider_auth!(
      :google_oauth2,
      uid: "oauth-new-#{SecureRandom.hex(4)}",
      email: email,
      first_name: "New",
      last_name: "OAuth"
    )

    assert_difference -> { User.count }, +1 do
      get user_google_oauth2_omniauth_callback_path
    end

    user = User.find_by!(email: email)
    assert_equal [{ user_id: user.id, method: :oauth, user_found: true }], @events
  end

  test "oauth link to an existing user does not emit" do
    email = "reg-event-link-#{SecureRandom.hex(4)}@example.com"
    existing = RecordingStudioUser.create_user!(
      email: email,
      password: "Password123!",
      first_name: "Existing",
      last_name: "User",
      time_zone: "UTC"
    )
    @events.clear
    mock_provider_auth!(
      :google_oauth2,
      uid: "oauth-link-#{SecureRandom.hex(4)}",
      email: email
    )

    assert_no_difference -> { User.count } do
      assert_difference -> { RecordingStudioUser::Identity.count }, +1 do
        get user_google_oauth2_omniauth_callback_path
      end
    end

    assert existing.identities.exists?(provider: "google_oauth2")
    assert_empty @events
  end

  test "oauth login for existing identity does not emit" do
    email = "reg-event-oauth-login-#{SecureRandom.hex(4)}@example.com"
    user = RecordingStudioUser.create_user!(
      email: email,
      password: "Password123!",
      first_name: "Return",
      last_name: "Visit",
      time_zone: "UTC"
    )
    uid = "oauth-return-#{SecureRandom.hex(4)}"
    user.identities.create!(provider: "google_oauth2", uid: uid, email: email)
    @events.clear
    mock_provider_auth!(:google_oauth2, uid: uid, email: email)

    assert_no_difference -> { User.count } do
      get user_google_oauth2_omniauth_callback_path
    end

    assert_empty @events
  end

  test "otp registration emits new event and keeps legacy otp event" do
    email = "reg-event-otp-#{SecureRandom.hex(4)}@example.com"
    post "#{new_user_registration_path}/otp", params: { user: { email: email } }
    user = User.find_by!(email: email)
    challenge = RecordingStudioUser::OtpChallenge.find_by!(user_id: user.id, purpose: "registration")
    code = challenge.decrypt_delivery_code!
    @events.clear
    @otp_events.clear

    post verify_user_registration_path, params: { code: code }

    user.reload
    assert user.confirmed?
    assert_equal [{ user_id: user.id, method: :otp, user_found: true }], @events
    assert_equal 1, @otp_events.size
    assert_equal user.id, @otp_events.first[:user_id]
    assert_equal challenge.id, @otp_events.first[:challenge_id]
  end

  test "registration completed event fires only after commit" do
    user = RecordingStudioUser.create_user!(
      email: "reg-event-commit-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "After",
      last_name: "Commit",
      time_zone: "UTC"
    )
    @events.clear
    found_inside = nil

    ActiveRecord::Base.transaction do
      RecordingStudioUser::RegistrationCompleted.emit!(user_id: user.id, method: :password)
      assert_empty @events

      found_inside = User.find_by(id: user.id)
      raise ActiveRecord::Rollback
    end

    assert found_inside
    assert_empty @events

    RecordingStudioUser::RegistrationCompleted.emit!(user_id: user.id, method: :password)

    assert_equal 1, @events.size
    assert_equal user.id, @events.first[:user_id]
    assert @events.first[:user_found]
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
