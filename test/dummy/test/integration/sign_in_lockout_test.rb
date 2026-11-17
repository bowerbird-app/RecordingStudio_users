# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SignInLockoutTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @config = RecordingStudioUser.config
    @original = %i[
      otp_lockout_max_failures otp_lockout_window otp_lockout_duration otp_max_attempts otp_expires_in
      password_lockout_max_failures password_lockout_window password_lockout_duration
      password_sign_in_email_limit password_sign_in_ip_limit
    ].index_with { |setting| @config.public_send(setting) }
    @config.otp_max_attempts = 20
    @config.otp_expires_in = 1.hour
    @config.otp_lockout_max_failures = 4
    @config.otp_lockout_window = 2.hours
    @config.otp_lockout_duration = 2.minutes
    @config.password_lockout_max_failures = 3
    @config.password_lockout_window = 2.hours
    @config.password_lockout_duration = 2.minutes
    @config.password_sign_in_email_limit = 50
    @config.password_sign_in_ip_limit = 50
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    @original.each { |setting, value| @config.public_send("#{setting}=", value) }
  end

  test "code lock counts reissued challenges and every purpose" do
    user = password_user("otp-spread")
    registration = RecordingStudioUser::OtpChallenge.issue_for!(user: user, purpose: "registration", code: "111111")
    assert_equal :invalid_code, fail_code!(registration, "registration").reason
    refute RecordingStudioUser::Services::AccountLockout.locked?(user, :otp)

    session = {}
    first = issue_login!(user, session)
    fail_code!(first.challenge, "login")
    second = issue_login!(user, session)
    assert first.challenge.reload.revoked?
    refute RecordingStudioUser::Services::AccountLockout.locked?(user, :otp)

    fail_code!(second.challenge, "login")
    ActionMailer::Base.deliveries.clear
    locked = fail_code!(second.challenge, "login")

    assert_equal :invalid_code, locked.reason
    assert_equal 4, RecordingStudioUser::Services::AccountLockout.otp_failure_count(user)
    assert RecordingStudioUser::Services::AccountLockout.locked?(user, :otp)
    assert_equal 1, lock_notifications(user).count
    assert_equal 1, lock_mails("otp").size
    assert_lock_mail("otp")

    code = second.challenge.reload.decrypt_delivery_code!
    correct = verify!(second.challenge, "login", code)
    wrong = fail_code!(second.challenge, "login")
    assert_equal :invalid_code, correct.reason
    assert_equal wrong.reason, correct.reason
    refute correct.success?
    assert_equal 1, lock_notifications(user).count

    travel 3.minutes

    refute RecordingStudioUser::Services::AccountLockout.locked?(user, :otp)
    opened = verify!(second.challenge, "login", code)
    assert opened.success?
  end

  test "a successful code clears earlier failures" do
    user = password_user("otp-reset")
    session = {}
    first = issue_login!(user, session)
    3.times { fail_code!(first.challenge, "login") }
    refute RecordingStudioUser::Services::AccountLockout.locked?(user, :otp)

    code = first.challenge.decrypt_delivery_code!
    assert verify!(first.challenge, "login", code).success?

    second = issue_login!(user, session)
    3.times { fail_code!(second.challenge, "login") }
    refute RecordingStudioUser::Services::AccountLockout.locked?(user, :otp)
    assert_equal 3, RecordingStudioUser::Services::AccountLockout.otp_failure_count(user)
  end

  test "a locked account is told a code was sent and nothing is issued" do
    user = password_user("otp-silent")
    lock_otp!(user)

    assert_no_difference -> { RecordingStudioUser::OtpChallenge.where(user: user).count } do
      post "#{new_user_session_path}/otp", params: { user: { email: user.email } }
    end
    assert_redirected_to verify_user_session_path
    assert_equal I18n.t("recording_studio_user.auth.eligible_code_sent"), flash[:notice]

    post "/users/sign_in/resend"
    assert_redirected_to verify_user_session_path
    assert_equal I18n.t("recording_studio_user.auth.eligible_code_sent"), flash[:notice]
    assert_equal 1, lock_notifications(user).count
  end

  test "a correct code and a wrong code render the same page while locked" do
    user = password_user("otp-page")
    post "#{new_user_session_path}/otp", params: { user: { email: user.email } }
    assert_redirected_to verify_user_session_path
    4.times { post verify_user_session_path, params: { code: "000000" } }
    assert_response :unprocessable_entity

    post verify_user_session_path, params: { code: "000000" }
    wrong = page_signature

    code = RecordingStudioUser::OtpChallenge.find(session[:otp_challenge_id]).decrypt_delivery_code!
    post verify_user_session_path, params: { code: code }
    correct = page_signature

    assert_equal wrong, correct
    assert_equal I18n.t("recording_studio_user.auth.verify.invalid_code"), flash[:alert]
    refute_match(/locked|too many/i, response.body)
  end

  test "password lockout matches a wrong password, emails once, and unlocks" do
    email = "password-lock-#{SecureRandom.hex(4)}@example.com"
    user = password_user(email)
    mismatch = I18n.t("recording_studio_user.auth.email_or_password_mismatch")

    2.times { post_sign_in(email: email, password: "not-the-password") }
    refute RecordingStudioUser::Services::AccountLockout.locked?(user, :password)
    ActionMailer::Base.deliveries.clear

    post_sign_in(email: email, password: "not-the-password")
    assert_password_mismatch(mismatch)
    assert_equal 1, lock_mails("password").size

    post_sign_in(email: email, password: "not-the-password")
    wrong = page_signature
    post_sign_in(email: email, password: "Password123!")
    correct = page_signature

    assert_equal wrong, correct
    assert_password_mismatch(mismatch)
    assert_equal 1, lock_mails("password").size
    assert_lock_mail("password")

    travel 3.minutes

    post_sign_in(email: email, password: "Password123!")
    assert_redirected_to root_path
    refute RecordingStudioUser::Services::AccountLockout.locked?(user, :password)
    assert_equal 0, RecordingStudioUser::PasswordFailure.where(user: user).count
  end

  test "a successful password sign-in clears earlier failures" do
    email = "password-reset-#{SecureRandom.hex(4)}@example.com"
    user = password_user(email)

    2.times { post_sign_in(email: email, password: "not-the-password") }
    post_sign_in(email: email, password: "Password123!")
    assert_redirected_to root_path
    assert_equal 0, RecordingStudioUser::PasswordFailure.where(user: user).count

    sign_out :user
    2.times { post_sign_in(email: email, password: "not-the-password") }
    refute RecordingStudioUser::Services::AccountLockout.locked?(user, :password)
  end

  test "code and password lockouts do not block each other" do
    email = "split-lock-#{SecureRandom.hex(4)}@example.com"
    user = password_user(email)
    lock_otp!(user)

    post_sign_in(email: email, password: "Password123!")
    assert_redirected_to root_path
    assert RecordingStudioUser::Services::AccountLockout.locked?(user, :otp)
    sign_out :user

    other = "split-password-#{SecureRandom.hex(4)}@example.com"
    other_user = password_user(other)
    3.times { post_sign_in(email: other, password: "not-the-password") }
    assert RecordingStudioUser::Services::AccountLockout.locked?(other_user, :password)

    session = {}
    issued = issue_login!(other_user, session)
    code = issued.challenge.decrypt_delivery_code!
    assert verify!(issued.challenge, "login", code).success?
    assert RecordingStudioUser::Services::AccountLockout.locked?(other_user, :password)
  end

  private

  def password_user(label)
    email = label.include?("@") ? label : "#{label}-#{SecureRandom.hex(4)}@example.com"
    user = RecordingStudioUser.create_user!(
      email: email,
      password: "Password123!",
      first_name: "Lock",
      last_name: "Out",
      time_zone: "UTC",
      confirm: true
    )
    accept_pending_live_terms!(user)
    sign_out :user
    user
  end

  def issue_login!(user, session)
    RecordingStudioUser::Services::IssueOtp.call(
      user: user, purpose: :login, session: session, checked_keys: []
    )
  end

  def fail_code!(challenge, purpose)
    verify!(challenge, purpose, "000000")
  end

  def verify!(challenge, purpose, code)
    session = { otp_challenge_id: challenge.id, otp_purpose: purpose }
    RecordingStudioUser.verify_otp!(
      challenge_id: challenge.id, code: code, purpose: purpose, session: session
    )
  end

  def lock_otp!(user)
    session = {}
    issued = issue_login!(user, session)
    4.times { fail_code!(issued.challenge, "login") }
    assert RecordingStudioUser::Services::AccountLockout.locked?(user, :otp)
  end

  def lock_notifications(user)
    RecordingStudioNotifications::Notification.where(recipient: user, notification_type: "sign_in_lockout")
  end

  def lock_mails(kind)
    subject = I18n.t("recording_studio_user.auth.lockout.#{kind}.title")
    ActionMailer::Base.deliveries.select { |mail| mail.subject == subject }
  end

  def assert_lock_mail(kind)
    copy = I18n.t("recording_studio_user.auth.lockout.#{kind}.body")
    mail = lock_mails(kind).first
    assert_includes mail.text_part.body.to_s, copy
    assert_includes mail.html_part.body.to_s, copy
    refute_match(/\d/, copy)
    refute_match(/\d{6}/, mail.subject.to_s)
  end

  def post_sign_in(email:, password:)
    post "/users/sign_in/password",
         params: { user: { email: email, password: password } },
         env: { "REMOTE_ADDR" => "203.0.113.77" }
  end

  def assert_password_mismatch(message)
    assert_response :unprocessable_entity
    assert_equal message, flash[:alert]
    refute_match(/locked|too many/i, response.body)
  end

  def page_signature
    body = response.body
    body = body.gsub(/authenticity_token" value="[^"]+"/, "TOKEN")
    body = body.gsub(/csrf-token" content="[^"]+"/, "TOKEN")
    body = body.gsub(/id="[^"]+"/, 'id="ID"')
    body = body.gsub(/for="[^"]+"/, 'for="ID"')
    body = body.gsub(/error-id-value="[^"]+"/, 'error-id-value="ID"')
    [response.status, flash[:alert], flash[:notice], body]
  end
end
