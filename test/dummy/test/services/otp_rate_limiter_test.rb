# frozen_string_literal: true

require "test_helper"

class OtpRateLimiterTest < ActiveSupport::TestCase
  setup do
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @previous_cooldown = RecordingStudioUser.config.otp_resend_cooldown
  end

  teardown do
    Rails.cache = @previous_cache
    RecordingStudioUser.config.otp_resend_cooldown = @previous_cooldown
  end

  test "first allow_request succeeds and second raises RateLimited with scope" do
    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "user@example.com")

    error = assert_raises(RecordingStudioUser::Services::OtpRateLimiter::RateLimited) do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "user@example.com")
    end

    assert_equal :issue, error.scope
    assert_equal RecordingStudioUser::RateLimited, error.class
  end

  test "different keys and scopes are independent buckets" do
    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "a@example.com")
    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "b@example.com")
    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "a@example.com")

    assert_raises(RecordingStudioUser::RateLimited) do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "a@example.com")
    end
  end

  test "resend cooldown uses otp_resend_cooldown config" do
    RecordingStudioUser.config.otp_resend_cooldown = 2.seconds
    assert_equal 2.seconds, RecordingStudioUser::Services::OtpRateLimiter.cooldown_for(:resend)
    assert_equal 1.minute, RecordingStudioUser::Services::OtpRateLimiter.cooldown_for(:issue)

    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "cooldown@example.com")
    assert_raises(RecordingStudioUser::RateLimited) do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "cooldown@example.com")
    end

    travel 3.seconds

    assert_nothing_raised do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "cooldown@example.com")
    end
  end

  test "stores an integer counter under the otp:rl key and ignores legacy boolean keys" do
    legacy_key = "recording_studio_user:otp:issue:legacy@example.com"
    counter_key = "recording_studio_user:otp:rl:issue:legacy@example.com"
    Rails.cache.write(legacy_key, true, expires_in: 1.minute)

    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "legacy@example.com")

    assert_equal true, Rails.cache.read(legacy_key)
    assert_equal 1, Rails.cache.read(counter_key)

    assert_raises(RecordingStudioUser::RateLimited) do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "legacy@example.com")
    end
    assert_equal 2, Rails.cache.read(counter_key)
  end

  test "fail_closed blocks when the cache raises a connection error" do
    failing = Object.new
    def failing.increment(*)
      raise Errno::ECONNREFUSED, "cache down"
    end
    def failing.write(*)
      raise Errno::ECONNREFUSED, "cache down"
    end
    def failing.read(*)
      raise Errno::ECONNREFUSED, "cache down"
    end

    Rails.cache = failing

    error = assert_raises(RecordingStudioUser::RateLimited) do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "down@example.com")
    end
    assert_equal :issue, error.scope
  end
end
