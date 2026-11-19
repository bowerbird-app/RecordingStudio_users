# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

module SignupSourceRequestPlant
  def plant_signup_source_for_test
    raw = request.headers["X-Signup-Source"].presence
    email = request.headers["X-Start-Otp"].presence
    return if raw.blank? && email.blank?

    source = raw.present? ? JSON.parse(raw) : nil
    if email
      RecordingStudioUser.start_otp_challenge!(request: request, email: email, source: source)
    else
      RecordingStudioUser.remember_signup_source!(request: request, source: source)
    end
  end
end

class SignupSourceTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  EVENT = RecordingStudioUser::RegistrationCompleted::EVENT
  SOURCE_KEY = RecordingStudioUser::SignupSource::SESSION_KEY

  setup do
    @events = []
    @subscriber = ActiveSupport::Notifications.subscribe(EVENT) do |_name, _start, _finish, _id, payload|
      @events << payload
    end
    OmniAuth.config.test_mode = true
    clear_omniauth_mocks!
    @original_create_account = RecordingStudioUser.config.omniauth_create_account
    RecordingStudioUser.config.omniauth_create_account = true
    ActionMailer::Base.deliveries.clear
    Rails.cache.clear
    install_signup_source_plant!
  end

  teardown do
    ActiveSupport::Notifications.unsubscribe(@subscriber)
    clear_omniauth_mocks!
    RecordingStudioUser.config.omniauth_create_account = @original_create_account
  end

  test "start_otp_challenge stores source and a source param on the code post is ignored" do
    email = "source-direct-#{SecureRandom.hex(4)}@example.com"
    source = { "kind" => "press_contact", "recording_id" => 8, "early" => false }
    get new_user_session_path, headers: {
      "X-Signup-Source" => JSON.generate(source),
      "X-Start-Otp" => email
    }

    user = User.find_by!(email: email)
    refute_includes user.attributes.keys, "signup_source"
    assert_equal({ kind: "press_contact", recording_id: 8, early: false }, RecordingStudioUser::SignupSource.read(session))
    post recording_studio_user_otp_challenge_path, params: {
      code: registration_code(user),
      source: { kind: "from_params" }
    }

    assert_equal [expected_source(user, :otp, { kind: "press_contact", recording_id: 8, early: false })], @events
    assert_nil session[SOURCE_KEY]
    refute_stored_on_user_or_challenge!(user, "press_contact")
  end

  test "built-in otp signup keeps a remembered source and ignores a source param" do
    email = "source-otp-#{SecureRandom.hex(4)}@example.com"
    get "#{new_user_registration_path}/otp", headers: signup_source_header("kind" => "kit_download")

    post "#{new_user_registration_path}/otp", params: {
      user: { email: email },
      source: { kind: "from_params" }
    }
    user = User.find_by!(email: email)
    assert_equal "kit_download", RecordingStudioUser::SignupSource.read(session)[:kind]

    post verify_user_registration_path, params: { code: registration_code(user), source: { kind: "from_params" } }

    assert_equal [expected_source(user, :otp, { kind: "kit_download" })], @events
    assert_nil session[SOURCE_KEY]
  end

  test "password confirmation emits the remembered source and a second signup gets none" do
    email = "source-pw-#{SecureRandom.hex(4)}@example.com"
    get new_user_registration_path, headers: signup_source_header("kind" => "share_request", "recording_id" => 15)

    post user_registration_path, params: {
      user: { email: email, password: "Password123!", password_confirmation: "Password123!" },
      source: { kind: "from_params" }
    }
    assert_empty @events
    assert_equal "share_request", RecordingStudioUser::SignupSource.read(session)[:kind]

    user = User.find_by!(email: email)
    post verify_user_registration_path, params: { code: confirmation_code, source: { kind: "from_params" } }

    assert_equal [expected_source(user, :password, { kind: "share_request", recording_id: 15 })], @events
    assert_nil session[SOURCE_KEY]
    refute_stored_on_user_or_challenge!(user, "share_request")

    sign_out :user
    second_email = "source-pw-next-#{SecureRandom.hex(4)}@example.com"
    post user_registration_path, params: {
      user: { email: second_email, password: "Password123!", password_confirmation: "Password123!" }
    }
    post verify_user_registration_path, params: { code: confirmation_code }

    second = User.find_by!(email: second_email)
    assert_equal({ user_id: second.id, method: :password }, @events.last)
    refute @events.last.key?(:source)
  end

  test "a new oauth user receives the remembered source" do
    email = "source-oauth-#{SecureRandom.hex(4)}@example.com"
    get new_user_session_path, headers: signup_source_header("kind" => "embargo", "early" => true)
    assert_equal({ kind: "embargo", early: true }, RecordingStudioUser::SignupSource.read(session))
    mock_provider_auth!(:google_oauth2, uid: "source-oauth-#{SecureRandom.hex(4)}", email: email)

    assert_difference -> { User.count }, +1 do
      get user_google_oauth2_omniauth_callback_path, params: { source: { kind: "from_params" } }
    end

    user = User.find_by!(email: email)
    assert_equal [expected_source(user, :oauth, { kind: "embargo", early: true })], @events
    assert_nil session[SOURCE_KEY]
    refute_includes user.attributes.values.map(&:to_s), "embargo"
  end

  test "params cannot supply a signup source" do
    otp_email = "source-param-otp-#{SecureRandom.hex(4)}@example.com"
    post "#{new_user_registration_path}/otp", params: {
      user: { email: otp_email },
      source: { kind: "press_contact" }
    }
    assert_nil session[SOURCE_KEY]
    post verify_user_registration_path, params: { code: registration_code(User.find_by!(email: otp_email)) }
    refute @events.last.key?(:source)

    Rails.cache.clear
    password_email = "source-param-pw-#{SecureRandom.hex(4)}@example.com"
    post user_registration_path, params: {
      user: { email: password_email, password: "Password123!", password_confirmation: "Password123!" },
      source: { kind: "press_contact" }
    }
    assert_nil session[SOURCE_KEY]
    post verify_user_registration_path, params: { code: confirmation_code }
    refute @events.last.key?(:source)

    Rails.cache.clear
    direct_email = "source-param-direct-#{SecureRandom.hex(4)}@example.com"
    post recording_studio_user_otp_start_path, params: {
      email: direct_email,
      source: { kind: "press_contact" }
    }
    assert_nil session[SOURCE_KEY]
    post recording_studio_user_otp_challenge_path, params: {
      code: registration_code(User.find_by!(email: direct_email)),
      source: { kind: "press_contact" }
    }
    refute @events.last.key?(:source)

    Rails.cache.clear
    sign_out :user
    oauth_email = "source-param-oauth-#{SecureRandom.hex(4)}@example.com"
    mock_provider_auth!(:google_oauth2, uid: "source-param-oauth-#{SecureRandom.hex(4)}", email: oauth_email)
    before = @events.size
    post "#{user_google_oauth2_omniauth_authorize_path}?source[kind]=press_contact"
    assert_response :redirect
    follow_redirect!
    follow_redirect! if response.redirect?
    assert_equal before + 1, @events.size
    refute @events.last.key?(:source)
    assert_nil session[SOURCE_KEY]
    refute_includes User.find_by!(email: oauth_email).attributes.values.map(&:to_s), "press_contact"
  end

  test "password sign-in and an existing oauth user do not emit or keep a source" do
    email = "source-login-#{SecureRandom.hex(4)}@example.com"
    user = RecordingStudioUser.create_user!(
      email: email,
      password: "Password123!",
      first_name: "Log",
      last_name: "In",
      time_zone: "UTC",
      confirm: true
    )
    accept_pending_live_terms!(user)
    get new_user_session_path, headers: signup_source_header("kind" => "press_contact")
    get new_user_session_path
    assert_equal({ kind: "press_contact" }, RecordingStudioUser::SignupSource.read(session))

    post user_session_path, params: { user: { email: email, password: "Password123!" } }

    assert_redirected_to root_path
    assert_empty @events
    assert_nil session[SOURCE_KEY]

    sign_out :user
    uid = "source-oauth-login-#{SecureRandom.hex(4)}"
    user.identities.create!(provider: "google_oauth2", uid: uid, email: email)
    get new_user_session_path, headers: signup_source_header("kind" => "embargo")
    assert_equal({ kind: "embargo" }, RecordingStudioUser::SignupSource.read(session))
    mock_provider_auth!(:google_oauth2, uid: uid, email: email)

    assert_no_difference -> { User.count } do
      get user_google_oauth2_omniauth_callback_path
    end

    assert_empty @events
    assert_nil session[SOURCE_KEY]
  end

  private

  def install_signup_source_plant!
    [
      RecordingStudioUser::Auth::SessionsController,
      RecordingStudioUser::Auth::RegistrationsController
    ].each do |controller|
      next if controller.ancestors.include?(SignupSourceRequestPlant)

      controller.prepend(SignupSourceRequestPlant)
      controller.before_action :plant_signup_source_for_test
    end
  end

  def signup_source_header(source)
    { "X-Signup-Source" => JSON.generate(source) }
  end

  def expected_source(user, method, source)
    { user_id: user.id, method: method, source: source }
  end

  def confirmation_code
    RecordingStudioUser.otp_message(session[:otp_challenge_id]).fetch(:body)[/\d{6}/]
  end

  def registration_code(user)
    RecordingStudioUser::OtpChallenge.where(user: user, purpose: "registration", consumed_at: nil, revoked_at: nil)
                                     .order(created_at: :desc)
                                     .first!
                                     .decrypt_delivery_code!
  end

  def refute_stored_on_user_or_challenge!(user, marker)
    refute_includes user.reload.attributes.values.map(&:to_s), marker
    challenge = RecordingStudioUser::OtpChallenge.where(user: user).order(created_at: :desc).first!
    refute_includes challenge.attributes.keys, "signup_source"
    refute_includes challenge.attributes.values.map(&:to_s), marker
  end

  def clear_omniauth_mocks!
    %i[google_oauth2 microsoft_graph apple linkedin instagram].each do |provider|
      OmniAuth.config.mock_auth[provider] = nil
    end
  end

  def mock_provider_auth!(provider, uid:, email:, first_name: "New", last_name: "Person")
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
