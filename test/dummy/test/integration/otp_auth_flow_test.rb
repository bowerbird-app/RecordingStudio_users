# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "rake"

class OtpAuthFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    ActionMailer::Base.deliveries.clear
    Rails.cache.clear
  end

  # --- Happy paths ---

  test "password registration stores authentication_method password and creates profile" do
    email = "password-reg-#{SecureRandom.hex(4)}@example.com"

    assert_difference -> { User.count }, +1 do
      post user_registration_path, params: {
        user: { email: email, password: "Password123!", password_confirmation: "Password123!" }
      }
    end

    user = User.find_by!(email: email)
    assert user.password_authentication_method?
    assert RecordingStudioUser.profile_for(user)
    assert_redirected_to root_path

    sign_out_user!
    post user_session_path, params: { user: { email: email, password: "Password123!" } }
    assert_redirected_to root_path
  end

  test "OTP registration creates unconfirmed user without profile or password" do
    email = "otp-reg-#{SecureRandom.hex(4)}@example.com"

    assert_difference -> { User.count }, +1 do
      post "#{new_user_registration_path}/otp", params: { user: { email: email } }
    end

    user = User.find_by!(email: email)
    assert user.otp_authentication_method?
    refute user.confirmed?
    assert_nil RecordingStudioUser.profile_for(user)
    assert user.encrypted_password.blank?

    assert_redirected_to verify_user_registration_path
    assert session[:otp_challenge_id].present?
    assert_equal user.id, session[:otp_user_id]
  end

  test "correct registration OTP confirms user creates profile and signs in" do
    email = "otp-verify-#{SecureRandom.hex(4)}@example.com"
    start_otp_registration!(email)

    user = User.find_by!(email: email)
    code = current_otp_code(user, "registration")

    post "#{verify_user_registration_path}", params: { code: code }
    follow_redirect!

    user.reload
    assert user.confirmed?
    assert RecordingStudioUser.profile_for(user)
    get recording_studio_users.profile_path
    assert_response :success
  end

  test "OTP user cannot password login" do
    otp_email = "otp-only-#{SecureRandom.hex(4)}@example.com"
    start_otp_registration!(otp_email)
    user = User.find_by!(email: otp_email)
    code = current_otp_code(user, "registration")
    post "#{verify_user_registration_path}", params: { code: code }
    follow_redirect!
    sign_out_user!
    clear_otp_session!

    post user_session_path, params: { user: { email: otp_email, password: "Password123!" } }
    assert_response :unprocessable_entity
    assert_includes response.body, "email codes"
  end

  test "password user can request a login OTP" do
    password_email = "password-only-#{SecureRandom.hex(4)}@example.com"
    RecordingStudioUser.create_user!(
      email: password_email,
      password: "Password123!",
      first_name: "Pass",
      last_name: "Word",
      time_zone: "UTC"
    )

    post "#{new_user_session_path}/otp", params: { user: { email: password_email } }
    assert_redirected_to verify_user_session_path
    assert session[:otp_challenge_id].present?
    assert_equal User.find_by!(email: password_email).id, session[:otp_user_id]
  end

  test "OTP user password reset redirects with generic OTP guidance" do
    email = "otp-reset-#{SecureRandom.hex(4)}@example.com"
    confirm_otp_user!(email)
    sign_out_user!

    post user_password_path, params: { user: { email: email } }
    assert_redirected_to new_user_session_path
    assert_match(/email codes/i, flash[:notice])
  end

  test "existing email cannot register with the other method" do
    email = "cross-method-#{SecureRandom.hex(4)}@example.com"
    RecordingStudioUser.create_user!(
      email: email,
      password: "Password123!",
      first_name: "Cross",
      last_name: "Method",
      time_zone: "UTC"
    )

    post "#{new_user_registration_path}/otp", params: { user: { email: email } }
    assert_redirected_to new_user_session_path

    sign_out_user!
    otp_email = "otp-cross-#{SecureRandom.hex(4)}@example.com"
    start_otp_registration!(otp_email)
    confirm_otp_user!(otp_email)
    sign_out_user!

    post user_registration_path, params: {
      user: { email: otp_email, password: "Password123!", password_confirmation: "Password123!" }
    }
    assert_response :unprocessable_entity
    assert_includes response.body, "already has an account"
  end

  test "repeat OTP registration for same unconfirmed email reuses user" do
    email = "reuse-#{SecureRandom.hex(4)}@example.com"
    start_otp_registration!(email)
    first_user = User.find_by!(email: email)

    sign_out_user!
    post "#{new_user_registration_path}/otp", params: { user: { email: email } }

    assert_equal first_user.id, User.find_by!(email: email).id
    assert_equal 1, User.where(email: email).count
  end

  test "confirmed email registration directs to sign-in" do
    email = "confirmed-reg-#{SecureRandom.hex(4)}@example.com"
    confirm_otp_user!(email)
    sign_out_user!

    post "#{new_user_registration_path}/otp", params: { user: { email: email } }
    assert_redirected_to new_user_session_path
  end

  test "unknown OTP login email gives same notice without creating user" do
    email = "unknown-#{SecureRandom.hex(4)}@example.com"

    assert_no_difference -> { User.count } do
      post "#{new_user_session_path}/otp", params: { user: { email: email } }
    end

    assert_redirected_to verify_user_session_path
    assert_match(/eligible account/i, flash[:notice])
    follow_redirect!
    assert_response :success
    assert_select "input[name='code']"
    assert_includes response.body, "Enter your code"
  end

  test "ineligible and eligible OTP login emails render the same verify page" do
    unconfirmed_email = "unconfirmed-enum-#{SecureRandom.hex(4)}@example.com"
    start_otp_registration!(unconfirmed_email)
    sign_out_user!
    clear_otp_session!

    post "#{new_user_session_path}/otp", params: { user: { email: unconfirmed_email } }
    follow_redirect!
    assert_response :success
    assert_select "input[name='code']"
    assert_includes response.body, "Enter your code"

    otp_email = "otp-enum-#{SecureRandom.hex(4)}@example.com"
    confirm_otp_user!(otp_email)
    sign_out_user!
    clear_otp_session!

    post "#{new_user_session_path}/otp", params: { user: { email: otp_email } }
    follow_redirect!
    assert_response :success
    assert_select "input[name='code']"
    assert_includes response.body, "Enter your code"
  end

  test "password account can sign in with a login code" do
    email = "password-otp-login-#{SecureRandom.hex(4)}@example.com"
    RecordingStudioUser.create_user!(
      email: email,
      password: "Password123!",
      first_name: "Pass",
      last_name: "Word",
      time_zone: "UTC"
    )

    post "#{new_user_session_path}/otp", params: { user: { email: email } }
    follow_redirect!
    assert_response :success

    user = User.find_by!(email: email)
    assert user.password_authentication_method?

    code = current_otp_code(user, "login")
    post verify_user_session_path, params: { code: code }
    assert_redirected_to root_path

    get recording_studio_users.profile_path
    assert_response :success
  end

  test "password account keeps working with its password after using a login code" do
    email = "password-both-#{SecureRandom.hex(4)}@example.com"
    RecordingStudioUser.create_user!(
      email: email,
      password: "Password123!",
      first_name: "Both",
      last_name: "Ways",
      time_zone: "UTC"
    )

    post "#{new_user_session_path}/otp", params: { user: { email: email } }
    user = User.find_by!(email: email)
    post verify_user_session_path, params: { code: current_otp_code(user, "login") }
    assert_redirected_to root_path

    sign_out_user!
    clear_otp_session!

    post user_session_path, params: { user: { email: email, password: "Password123!" } }
    assert_redirected_to root_path
    assert_equal "password", user.reload.authentication_method
  end

  test "login notification opens a protected page with the active code" do
    email = "notification-code-#{SecureRandom.hex(4)}@example.com"
    user = RecordingStudioUser.create_user!(
      email: email,
      password: "Password123!",
      first_name: "Notice",
      last_name: "Code",
      time_zone: "UTC"
    )
    sign_in user

    result = RecordingStudioUser.issue_otp!(user: user, purpose: :login)
    code = result.challenge.decrypt_delivery_code!
    notification = RecordingStudioNotifications::Notification
      .where(recipient: user, notification_type: "login_otp")
      .order(:created_at)
      .last!

    assert_equal "/recording_studio_users/otp_codes/#{result.challenge.id}", notification.url

    get notification.url

    assert_response :success
    assert_select "h1", text: "Your sign-in code"
    assert_includes response.body, code

    result.challenge.consume!
    get notification.url

    assert_response :success
    assert_includes response.body, "This code is no longer valid"
    refute_includes response.body, code
  end

  test "login code page expiry follows the configured otp_expires_in" do
    user = RecordingStudioUser.create_user!(
      email: "code-expiry-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Code",
      last_name: "Expiry",
      time_zone: "UTC"
    )
    sign_in user

    original = RecordingStudioUser.config.otp_expires_in
    RecordingStudioUser.config.otp_expires_in = 20.minutes
    challenge = RecordingStudioUser.issue_otp!(user: user, purpose: :login).challenge

    get recording_studio_users.otp_code_path(challenge)

    assert_response :success
    assert_includes response.body, "20 minutes"
  ensure
    RecordingStudioUser.config.otp_expires_in = original
  end

  test "login code page does not expose another user's code" do
    owner = RecordingStudioUser.create_user!(
      email: "code-owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Code",
      last_name: "Owner",
      time_zone: "UTC"
    )
    viewer = RecordingStudioUser.create_user!(
      email: "code-viewer-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Code",
      last_name: "Viewer",
      time_zone: "UTC"
    )
    challenge = RecordingStudioUser.issue_otp!(user: owner, purpose: :login).challenge
    code = challenge.decrypt_delivery_code!
    sign_in viewer

    get recording_studio_users.otp_code_path(challenge)

    assert_response :not_found
    refute_includes response.body, code
  end

  test "unconfirmed password account is not sent a login code" do
    email = "unconfirmed-password-#{SecureRandom.hex(4)}@example.com"
    user = User.create!(
      email: email,
      password: "Password123!",
      password_confirmation: "Password123!",
      authentication_method: "password"
    )
    user.update_column(:confirmed_at, nil)

    assert_no_difference -> { RecordingStudioUser::OtpChallenge.count } do
      post "#{new_user_session_path}/otp", params: { user: { email: email } }
    end

    assert_redirected_to verify_user_session_path
  end

  test "confirmed OTP user can sign in with a login code" do
    email = "otp-login-#{SecureRandom.hex(4)}@example.com"
    confirm_otp_user!(email)
    sign_out_user!
    clear_otp_session!

    post "#{new_user_session_path}/otp", params: { user: { email: email } }
    follow_redirect!
    assert_response :success

    user = User.find_by!(email: email)
    code = current_otp_code(user, "login")
    post verify_user_session_path, params: { code: code }
    assert_redirected_to root_path

    get recording_studio_users.profile_path
    assert_response :success
  end

  test "unconfirmed OTP user cannot access authenticated routes" do
    email = "unconfirmed-#{SecureRandom.hex(4)}@example.com"
    start_otp_registration!(email)

    get recording_studio_users.profile_path
    assert_redirected_to new_user_session_path
  end

  # --- Challenge security ---

  test "wrong code increments attempts and fifth failure revokes" do
    email = "attempts-#{SecureRandom.hex(4)}@example.com"
    start_otp_registration!(email)
    user = User.find_by!(email: email)
    challenge = active_challenge_for(user, "registration")

    4.times do
      post "#{verify_user_registration_path}", params: { code: "000000" }
      assert_response :unprocessable_entity
    end

    challenge.reload
    assert_equal 4, challenge.attempts_count

    post "#{verify_user_registration_path}", params: { code: "000000" }
    assert_response :unprocessable_entity
    challenge.reload
    assert challenge.revoked?
  end

  test "expired code is rejected" do
    email = "expired-#{SecureRandom.hex(4)}@example.com"
    start_otp_registration!(email)
    user = User.find_by!(email: email)
    code = current_otp_code(user, "registration")
    challenge = active_challenge_for(user, "registration")

    travel_to challenge.expires_at + 1.second do
      post "#{verify_user_registration_path}", params: { code: code }
      assert_response :unprocessable_entity
      assert_includes response.body, "expired"
    end
  end

  test "after resend old code fails" do
    email = "resend-#{SecureRandom.hex(4)}@example.com"
    start_otp_registration!(email)
    user = User.find_by!(email: email)
    old_code = current_otp_code(user, "registration")
    old_challenge_id = session[:otp_challenge_id]

    post resend_user_registration_path
    assert_redirected_to verify_user_registration_path
    refute_equal old_challenge_id, session[:otp_challenge_id]

    post "#{verify_user_registration_path}", params: { code: old_code }
    assert_response :unprocessable_entity
  end

  test "session-bound verification rejects mismatched session at service level" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: "session-bound-#{SecureRandom.hex(4)}@example.com")
    challenge = RecordingStudioUser::OtpChallenge.issue_for!(user: user, purpose: "registration", code: "123456")

    result = RecordingStudioUser.verify_otp!(
      challenge_id: challenge.id,
      code: "123456",
      purpose: "registration",
      session: { otp_challenge_id: SecureRandom.uuid, otp_purpose: "registration" }
    )

    refute result.success?
    assert_equal :session_mismatch, result.reason
  end

  test "auth controllers protect against CSRF" do
    assert_equal ActionController::RequestForgeryProtection::ProtectionMethods::Exception,
                 RecordingStudioUser::ApplicationController.forgery_protection_strategy
  end

  test "concurrent verify allows exactly one success" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: "concurrent-#{SecureRandom.hex(4)}@example.com")
    challenge = RecordingStudioUser::OtpChallenge.issue_for!(user: user, purpose: "registration", code: "123456")
    session_data = { otp_challenge_id: challenge.id, otp_purpose: "registration" }

    results = []
    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          results << RecordingStudioUser.verify_otp!(
            challenge_id: challenge.id,
            code: "123456",
            purpose: "registration",
            session: session_data.dup
          )
        end
      end
    end
    threads.each(&:join)

    assert_equal 1, results.count(&:success?)
    assert_equal 1, results.count { |r| !r.success? }
  end

  # --- Notifications ---

  test "registration notify uses email only with challenge id in metadata not code" do
    email = "notify-reg-#{SecureRandom.hex(4)}@example.com"
    start_otp_registration!(email)
    user = User.find_by!(email: email)
    challenge = active_challenge_for(user, "registration")

    notification = RecordingStudioNotifications::Notification.order(:created_at).last
    assert_equal "registration_otp", notification.notification_type
    assert_equal challenge.id, notification.metadata["otp_challenge_id"]
    refute notification.title.match?(/\d{6}/)
    assert_nil notification.body

    deliveries = notification.deliveries
    assert deliveries.any? { |d| d.channel == "email" }
    refute deliveries.any? { |d| d.channel == "push" }
  end

  test "registration email delivery contains code while notification record stays code-free" do
    email = "mail-reg-#{SecureRandom.hex(4)}@example.com"
    start_otp_registration!(email)
    user = User.find_by!(email: email)
    code = current_otp_code(user, "registration")
    notification = RecordingStudioNotifications::Notification.order(:created_at).last

    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.html_part.body.to_s, code
    assert_includes mail.text_part.body.to_s, code
    refute notification.title.include?(code)
    assert_nil notification.body
  end

  test "login OTP fans out to active push installations with code in payload" do
    email = "push-login-#{SecureRandom.hex(4)}@example.com"
    user = confirm_otp_user!(email)
    sign_out_user!
    clear_otp_session!

    create_push_installation!(user, fid: "fid-active-1")
    create_push_installation!(user, fid: "fid-active-2")
    disabled = create_push_installation!(user, fid: "fid-disabled")
    disabled.disable!

    with_stubbed_fcm_client do |client|
      post "#{new_user_session_path}/otp", params: { user: { email: email } }
      code = current_otp_code(user, "login")

      assert_equal 2, client.calls.size
      tokens = client.calls.map { |c| c[:token] }
      assert_includes tokens, "fid-active-1"
      assert_includes tokens, "fid-active-2"
      refute_includes tokens, "fid-disabled"
      assert client.calls.all? { |c| c[:body].include?(code) }
    end

    notification = RecordingStudioNotifications::Notification.order(:created_at).last
    refute notification.title.match?(/\d{6}/)
    assert_nil notification.body
  end

  test "registration does not request push" do
    email = "no-push-#{SecureRandom.hex(4)}@example.com"
    start_otp_registration!(email)

    notification = RecordingStudioNotifications::Notification.order(:created_at).last
    refute notification.deliveries.any? { |d| d.channel == "push" }
  end

  # --- Services ---

  test "create_unconfirmed_user does not create profile" do
    email = "no-profile-#{SecureRandom.hex(4)}@example.com"
    user = RecordingStudioUser.create_unconfirmed_user!(email: email)
    assert_nil RecordingStudioUser.profile_for(user)
  end

  test "complete_registration rolls back when profile recording fails" do
    email = "rollback-#{SecureRandom.hex(4)}@example.com"
    start_otp_registration!(email)
    user = User.find_by!(email: email)
    code = current_otp_code(user, "registration")
    challenge = active_challenge_for(user, "registration")

    original_record_profile = RecordingStudioUser.method(:record_profile!)
    begin
      RecordingStudioUser.define_singleton_method(:record_profile!) { |*| raise StandardError, "profile boom" }
      result = RecordingStudioUser.verify_otp!(
        challenge_id: challenge.id,
        code: code,
        purpose: "registration",
        session: { otp_challenge_id: challenge.id, otp_purpose: "registration" }
      )
      assert_raises(StandardError) do
        RecordingStudioUser.complete_registration!(user: result.user, challenge: result.challenge)
      end

      user.reload
      refute user.confirmed?
      assert_nil RecordingStudioUser.profile_for(user)
    ensure
      RecordingStudioUser.define_singleton_method(:record_profile!, original_record_profile)
    end
  end

  test "login challenge will not verify as registration" do
    user = confirm_otp_user!("purpose-#{SecureRandom.hex(4)}@example.com")
    sign_out_user!
    clear_otp_session!

    post "#{new_user_session_path}/otp", params: { user: { email: user.email } }
    code = current_otp_code(user, "login")

    post "#{verify_user_registration_path}", params: { code: code }
    assert_response :unprocessable_entity
  end

  # --- Cleanup ---

  test "cleanup task deletes abandoned users challenges and notifications" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("recording_studio_user:cleanup_otp")

    email = "cleanup-#{SecureRandom.hex(4)}@example.com"
    user = RecordingStudioUser.create_unconfirmed_user!(email: email)
    RecordingStudioUser.issue_otp!(user: user, purpose: :registration)
    notification = RecordingStudioNotifications::Notification.where(recipient: user).last
    assert notification

    user.update_column(:created_at, 8.days.ago)

    assert_difference -> { User.count }, -1 do
      assert_difference -> { RecordingStudioNotifications::Notification.count }, -1 do
        Rake::Task["recording_studio_user:cleanup_otp"].invoke
      end
    end
  ensure
    Rake::Task["recording_studio_user:cleanup_otp"].reenable
  end

  # --- Config enforcement ---

  test "disabled OTP registration returns not found" do
    original = RecordingStudioUser.config.otp_registration_enabled
    RecordingStudioUser.config.otp_registration_enabled = false

    get "#{new_user_registration_path}/otp"
    assert_response :not_found
  ensure
    RecordingStudioUser.config.otp_registration_enabled = original
  end

  test "disabled OTP login returns not found" do
    original_login = RecordingStudioUser.config.otp_login_enabled
    original_methods = RecordingStudioUser.config.instance_variable_get(:@registration_authentication_methods)
    RecordingStudioUser.config.instance_variable_set(:@registration_authentication_methods, %i[password])
    RecordingStudioUser.config.instance_variable_set(:@otp_login_enabled, false)

    get "#{new_user_session_path}/otp"
    assert_response :not_found
  ensure
    RecordingStudioUser.config.instance_variable_set(:@otp_login_enabled, original_login)
    RecordingStudioUser.config.instance_variable_set(:@registration_authentication_methods, original_methods)
  end

  private

  def clear_otp_session!
    session.delete(:otp_challenge_id)
    session.delete(:otp_purpose)
    session.delete(:otp_user_id)
  end

  def sign_out_user!
    sign_out :user
  rescue StandardError
    nil
  end

  def start_otp_registration!(email)
    post "#{new_user_registration_path}/otp", params: { user: { email: email } }
    assert_redirected_to verify_user_registration_path
  end

  def confirm_otp_user!(email, follow_redirect: false)
    start_otp_registration!(email)
    user = User.find_by!(email: email)
    code = current_otp_code(user, "registration")
    post "#{verify_user_registration_path}", params: { code: code }
    follow_redirect! if follow_redirect
    user.reload
    user
  end

  def current_otp_code(user, purpose)
    challenge = active_challenge_for(user, purpose)
    challenge.decrypt_delivery_code!
  end

  def active_challenge_for(user, purpose)
    RecordingStudioUser::OtpChallenge.where(user: user, purpose: purpose, consumed_at: nil, revoked_at: nil)
                                     .order(created_at: :desc)
                                     .first!
  end
end
