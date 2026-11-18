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

  test "a locked code request emails a sign-in link and the same notice" do
    open_user = password_user("otp-open-link")
    locked_user = password_user("otp-link")
    lock_otp!(locked_user)
    Rails.cache.clear
    ActionMailer::Base.deliveries.clear

    post_code(open_user.email, "203.0.113.10")
    open_response = [response.status, response.location, flash[:notice], flash[:alert]]

    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
    assert_no_difference -> { RecordingStudioUser::OtpChallenge.where(user: locked_user).count } do
      post_code(locked_user.email, "203.0.113.11")
    end

    assert_equal open_response, [response.status, response.location, flash[:notice], flash[:alert]]
    assert_equal I18n.t("recording_studio_user.auth.eligible_code_sent"), flash[:notice]
    mail = link_mails.last
    token = token_from(mail)
    assert token.present?
    refute_match(/locked|paused|too many/i, "#{mail.subject} #{mail.text_part.body}")
    stored = sign_in_link_notifications(locked_user).last
    refute_includes stored.body.to_s, token
    refute_includes stored.url.to_s, token
    assert_equal RecordingStudioUser::SignInLink.digest(token),
                 RecordingStudioUser::SignInLink.find_by!(user: locked_user).token_digest

    post "/users/sign_in/resend", env: { "REMOTE_ADDR" => "203.0.113.11" }
    assert_redirected_to verify_user_session_path
    assert_equal flash[:notice], open_response[2]
    assert_equal 1, link_mails.size
    assert_equal 1, lock_notifications(locked_user).count
  end

  test "a sign-in link is single-use, expires, is bound to its user, and clears both locks" do
    email = "link-user-#{SecureRandom.hex(4)}@example.com"
    user = password_user(email)
    other = password_user("link-other")
    lock_otp!(user)
    lock_otp!(other)
    3.times { post_sign_in(email: email, password: "not-the-password") }
    assert RecordingStudioUser::Services::AccountLockout.locked?(user, :password)
    Rails.cache.clear
    ActionMailer::Base.deliveries.clear

    post_code(user.email, "203.0.113.21")
    follow_mail_link(link_mails.last)

    assert_signed_in(user)
    refute RecordingStudioUser::Services::AccountLockout.locked?(user, :otp)
    refute RecordingStudioUser::Services::AccountLockout.locked?(user, :password)
    assert RecordingStudioUser::Services::AccountLockout.locked?(other, :otp)
    assert_equal 0, RecordingStudioUser::PasswordFailure.where(user: user).count
    assert_equal 0, RecordingStudioUser::Services::AccountLockout.otp_failure_count(user)

    sign_out :user
    used_mail = link_mails.last
    open_sign_in_link(used_mail)
    used_page = generic_sign_in_link_signature
    assert_nil session["warden.user.user.key"]
    post link_path(used_mail), params: { sign_in_token: token_from(used_mail) }
    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("recording_studio_user.auth.sign_in_link.invalid")
    assert_nil session["warden.user.user.key"]

    @config.otp_expires_in = 30.seconds
    @config.otp_lockout_duration = 10.minutes
    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
    post_code(other.email, "203.0.113.22")
    expired_mail = link_mails.last
    follow_redirect!
    travel 1.minute
    open_sign_in_link(expired_mail)
    expired_page = generic_sign_in_link_signature
    assert_nil session["warden.user.user.key"]
    assert RecordingStudioUser::Services::AccountLockout.locked?(other, :otp)

    get "/recording_studio_users/auth/sign_in/link", params: { sign_in_token: "not-a-real-token" }
    unknown_page = generic_sign_in_link_signature
    assert_nil session["warden.user.user.key"]
    assert_equal used_page, expired_page
    assert_equal used_page, unknown_page
  end

  test "a code-only account can sign in with the link" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: "code-only-#{SecureRandom.hex(4)}@example.com")
    user.update!(confirmed_at: Time.current)
    accept_pending_live_terms!(user)
    lock_otp!(user)
    Rails.cache.clear
    ActionMailer::Base.deliveries.clear

    post_code(user.email, "203.0.113.23")
    follow_mail_link(link_mails.last)

    assert_signed_in(user)
    refute RecordingStudioUser::Services::AccountLockout.locked?(user, :otp)
  end

  test "get sign-in link does not consume the token" do
    user = password_user("get-link")
    mail = request_link_mail(user, "203.0.113.32")
    link = RecordingStudioUser::SignInLink.find_by!(user: user)
    before = link.attributes.slice("token_digest", "consumed_at", "expires_at", "updated_at")

    open_sign_in_link(mail)
    assert_sign_in_confirm(user)
    assert_nil session["warden.user.user.key"]
    assert_equal before, link.reload.attributes.slice("token_digest", "consumed_at", "expires_at", "updated_at")

    open_sign_in_link(mail)
    assert_equal before, link.reload.attributes.slice("token_digest", "consumed_at", "expires_at", "updated_at")
  end

  test "post sign-in link signs in" do
    user = password_user("post-link")
    mail = request_link_mail(user, "203.0.113.33")

    follow_mail_link(mail)

    assert_signed_in(user)
    assert RecordingStudioUser::SignInLink.find_by!(user: user).consumed_at
  end

  test "post sign-in link without a csrf token fails" do
    user = password_user("csrf-link")
    mail = request_link_mail(user, "203.0.113.34")
    link = RecordingStudioUser::SignInLink.find_by!(user: user)
    raw = token_from(mail)

    with_forgery_protection do
      open_sign_in_link(mail)
      assert_sign_in_confirm(user)
      post confirm_sign_in_path, params: { sign_in_token: raw }

      assert_response :unprocessable_entity
      assert_nil session["warden.user.user.key"]
      assert_nil link.reload.consumed_at

      open_sign_in_link(mail)
      post confirm_sign_in_path, params: {
        sign_in_token: raw,
        authenticity_token: css_select("input[name=authenticity_token]").first["value"]
      }
      assert_signed_in(user)
    end

    assert link.reload.consumed_at
  end

  test "a successful sign-in retires unused sign-in links" do
    email = "retire-links-#{SecureRandom.hex(4)}@example.com"
    user = password_user(email)
    kept = unused_sign_in_link(password_user("retire-other"))

    password_link = unused_sign_in_link(user)
    post_sign_in(email: email, password: "Password123!")
    assert_redirected_to root_path
    assert password_link.reload.consumed_at
    assert_nil kept.reload.consumed_at
    sign_out :user

    Rails.cache.clear
    code_link = unused_sign_in_link(user)
    post "/users/sign_in/otp", params: { user: { email: email } }
    code = RecordingStudioUser::OtpChallenge.find(session[:otp_challenge_id]).decrypt_delivery_code!
    post verify_user_session_path, params: { code: code }
    assert_redirected_to root_path
    assert code_link.reload.consumed_at
    assert_nil kept.reload.consumed_at
    sign_out :user

    mail = request_link_mail(user, "203.0.113.35")
    issued = RecordingStudioUser::SignInLink.find_by!(user: user, consumed_at: nil)
    extra = unused_sign_in_link(user)
    follow_mail_link(mail)

    assert_signed_in(user)
    assert issued.reload.consumed_at
    assert extra.reload.consumed_at
    assert_nil kept.reload.consumed_at
  end

  test "a sign-in link email is queued the same way as a code email" do
    user = password_user("queued-link")
    lock_otp!(user)
    configuration = RecordingStudioNotifications.configuration
    previous_later = configuration.deliver_later
    previous_adapter = ActiveJob::Base.queue_adapter
    configuration.deliver_later = true
    ActiveJob::Base.queue_adapter = ActiveJob::QueueAdapters::TestAdapter.new
    Rails.cache.clear
    ActionMailer::Base.deliveries.clear

    post_code(user.email, "203.0.113.36")

    queued = ActiveJob::Base.queue_adapter.enqueued_jobs.select do |job|
      job[:job] == RecordingStudioNotifications::DeliveryJob
    end
    assert_equal 1, queued.size
    assert_empty ActionMailer::Base.deliveries
    stored = sign_in_link_notifications(user).last
    assert_includes stored.body.to_s, "sign_in_token="

    queued.each { |payload| payload[:job].deserialize(payload).perform_now }

    token = token_from(link_mails.last)
    assert token.present?
    stored.reload
    refute_includes stored.body.to_s, token
    refute_includes stored.url.to_s, token
  ensure
    configuration.deliver_later = previous_later if configuration
    ActiveJob::Base.queue_adapter = previous_adapter if previous_adapter
  end

  test "a password reset clears the password lock" do
    email = "reset-clears-#{SecureRandom.hex(4)}@example.com"
    user = password_user(email)
    3.times { post_sign_in(email: email, password: "not-the-password") }
    assert RecordingStudioUser::Services::AccountLockout.locked?(user, :password)

    raw_token, encrypted_token = Devise.token_generator.generate(User, :reset_password_token)
    user.update_columns(reset_password_token: encrypted_token, reset_password_sent_at: Time.current)
    put user_password_path, params: {
      user: {
        reset_password_token: raw_token,
        password: "BrandNewPassword123!",
        password_confirmation: "BrandNewPassword123!"
      }
    }

    assert_redirected_to root_path
    refute RecordingStudioUser::Services::AccountLockout.locked?(user, :password)
    assert_equal 0, RecordingStudioUser::PasswordFailure.where(user: user).count

    sign_out :user
    post_sign_in(email: email, password: "BrandNewPassword123!")
    assert_redirected_to root_path
  end

  test "an unknown email runs a password digest compare" do
    calls = count_password_compares do
      post_sign_in(email: "missing-#{SecureRandom.hex(4)}@example.com", password: "Password123!")
    end
    assert_equal 1, calls
    assert_password_mismatch(I18n.t("recording_studio_user.auth.email_or_password_mismatch"))

    user = password_user("known-compare")
    calls = count_password_compares do
      post_sign_in(email: user.email, password: "Password123!")
    end
    assert_equal 1, calls
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

  def assert_signed_in(user)
    assert_equal "/", URI.parse(response.location).path
    assert_equal user.id, session["warden.user.user.key"]&.dig(0, 0)
  end

  def count_password_compares
    calls = 0
    singleton = class << Devise::Encryptor; self; end
    original = Devise::Encryptor.method(:compare)
    singleton.define_method(:compare) do |*args, **kwargs|
      calls += 1
      original.call(*args, **kwargs)
    end
    yield
    calls
  ensure
    singleton.define_method(:compare) { |*args, **kwargs| original.call(*args, **kwargs) } if singleton && original
  end

  def post_code(email, ip)
    post "/users/sign_in/otp",
         params: { user: { email: email } },
         env: { "REMOTE_ADDR" => ip }
  end

  def link_mails
    subject = I18n.t("recording_studio_user.auth.sign_in_link.title")
    ActionMailer::Base.deliveries.select { |mail| mail.subject == subject }
  end

  def sign_in_link_notifications(user)
    RecordingStudioNotifications::Notification.where(recipient: user, notification_type: "sign_in_link")
  end

  def token_from(mail)
    mail.text_part.body.to_s[/sign_in_token=([^&\s]+)/, 1]
  end

  def request_link_mail(user, ip)
    lock_otp!(user)
    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
    post_code(user.email, ip)
    link_mails.last
  end

  def open_sign_in_link(mail)
    uri = URI.parse(mail.text_part.body.to_s[/https?:\/\/\S+/])
    get "#{uri.path}?#{uri.query}"
  end

  def follow_mail_link(mail)
    open_sign_in_link(mail)
    post confirm_sign_in_path, params: { sign_in_token: token_from(mail) }
  end

  def confirm_sign_in_path
    css_select("form").first["action"]
  end

  def link_path(mail)
    URI.parse(mail.text_part.body.to_s[/https?:\/\/\S+/]).path
  end

  def assert_sign_in_confirm(user)
    masked = RecordingStudioUser::OtpCodeForm.mask(user.email)
    assert_response :success
    assert_includes response.body, I18n.t("recording_studio_user.auth.sign_in_link.confirm", email: masked)
    refute_includes response.body, user.email
    assert_select "form[method=post]"
    assert_select "input[name=sign_in_token]"
    assert_select "button", text: I18n.t("recording_studio_user.auth.sign_in")
  end

  def generic_sign_in_link_signature
    assert_response :success
    assert_includes response.body, I18n.t("recording_studio_user.auth.sign_in_link.invalid")
    assert_select "form", count: 0
    assert_select "input[name=sign_in_token]", count: 0
    body = response.body.gsub(/sign_in_token=[^&"'\s]+/, "TOKEN")
    body = body.gsub(/authenticity_token" value="[^"]+"/, "TOKEN")
    body = body.gsub(/csrf-token" content="[^"]+"/, "TOKEN")
    [response.status, flash[:alert], flash[:notice], body]
  end

  def unused_sign_in_link(user)
    RecordingStudioUser::SignInLink.create!(
      user: user,
      token_digest: RecordingStudioUser::SignInLink.digest(SecureRandom.urlsafe_base64(32)),
      expires_at: 1.hour.from_now
    )
  end

  def with_forgery_protection
    controllers = [ActionController::Base, RecordingStudioUser::ApplicationController]
    originals = controllers.to_h { |controller| [controller, controller.allow_forgery_protection] }
    controllers.each { |controller| controller.allow_forgery_protection = true }
    yield
  ensure
    originals&.each { |controller, value| controller.allow_forgery_protection = value }
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
