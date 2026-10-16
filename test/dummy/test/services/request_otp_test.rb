# frozen_string_literal: true

require "test_helper"

class RequestOtpTest < ActiveSupport::TestCase
  setup do
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "a throttled new email creates no user" do
    email = unique_email("throttled")
    digest = RecordingStudioUser::Services::OtpRateLimiter.email_key(email)
    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: digest)

    assert_no_difference -> { User.count } do
      result = request_otp(email, :registration)
      assert result.throttled?
      assert_nil result.challenge
    end
    assert_nil User.find_by(email: email)
  end

  test "a blocked ip does not consume the email bucket or create a user" do
    email = unique_email("blocked-ip")
    ip = "198.51.100.20"
    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: ip)
    digest = RecordingStudioUser::Services::OtpRateLimiter.email_key(email)

    assert_no_difference -> { User.count } do
      result = request_otp(email, :registration, request: Struct.new(:remote_ip).new(ip))
      assert result.throttled?
    end

    assert_nil Rails.cache.read("recording_studio_user:otp:rl:issue:#{digest}")
    assert_equal 1, Rails.cache.read("recording_studio_user:otp:rl:issue:#{ip}")
  end

  test "registration returns issued or suppressed without raising for every kind of email" do
    unknown = unique_email("unknown")
    existing = confirmed_user("existing")
    password = password_user("password")
    disabled = confirmed_user("disabled")

    issued = request_otp(unknown, :registration)
    assert issued.issued?
    assert User.find_by!(email: unknown).registered_with_otp?

    with_disabled_email(disabled.email) do
      assert request_otp(disabled.email, :registration).suppressed?
    end
    assert request_otp(existing.email, :registration).suppressed?
    assert request_otp(password.email, :registration).suppressed?
    assert_nil open_challenge(existing)
    assert_nil open_challenge(password)
    assert_nil open_challenge(disabled)
  end

  test "login suppresses unknown, disabled, and unconfirmed addresses" do
    unknown = unique_email("missing")
    disabled = confirmed_user("inactive")
    unconfirmed = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("pending"))
    password = password_user("signin")

    assert_no_difference -> { User.count } do
      assert request_otp(unknown, :login).suppressed?
    end

    with_disabled_email(disabled.email) do
      result = request_otp(disabled.email, :login)
      assert result.suppressed?
      assert_nil result.challenge
    end
    assert request_otp(unconfirmed.email, :login).suppressed?
    assert request_otp(password.email, :login).issued?
  end

  test "issue_otp does not reserve keys that were already checked" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("checked"))
    digest = RecordingStudioUser::Services::OtpRateLimiter.email_key(user.email)
    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: digest)

    result = RecordingStudioUser::Services::IssueOtp.call(
      user: user,
      purpose: :registration,
      checked_keys: [ digest ]
    )

    assert result.issued?
    assert_equal 1, Rails.cache.read("recording_studio_user:otp:rl:issue:#{digest}")
  end

  test "resend uses the email digest" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("resend"))
    request_otp(user.email, :registration)

    resent = RecordingStudioUser.resend_otp!(user: user, purpose: :registration, request: nil, session: nil)
    digest = RecordingStudioUser::Services::OtpRateLimiter.email_key(user.email)

    assert resent.issued?
    assert_equal 1, Rails.cache.read("recording_studio_user:otp:rl:resend:#{digest}")
    assert_nil Rails.cache.read("recording_studio_user:otp:rl:resend:#{user.email}")
  end

  private

  def request_otp(email, purpose, request: nil, session: nil)
    RecordingStudioUser.request_otp!(email: email, purpose: purpose, request: request, session: session)
  end

  def unique_email(label)
    "#{label}-#{SecureRandom.hex(4)}@example.com"
  end

  def confirmed_user(label)
    RecordingStudioUser.create_user!(
      email: unique_email(label),
      password: "Password123!",
      first_name: "Case",
      last_name: "Study",
      time_zone: "UTC"
    )
  end

  def password_user(label)
    confirmed_user(label)
  end

  def open_challenge(user)
    RecordingStudioUser::OtpChallenge.find_by(user: user, purpose: "registration", consumed_at: nil, revoked_at: nil)
  end

  def with_disabled_email(email)
    User.class_eval do
      alias_method :active_for_authentication_without_test_disable, :active_for_authentication?
      define_method(:active_for_authentication?) do
        return false if self.email == email

        active_for_authentication_without_test_disable
      end
    end
    yield
  ensure
    User.class_eval do
      alias_method :active_for_authentication?, :active_for_authentication_without_test_disable
      remove_method :active_for_authentication_without_test_disable
    end
  end
end
