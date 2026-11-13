# frozen_string_literal: true

require "test_helper"

class AuthRateLimiterTest < ActiveSupport::TestCase
  setup do
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @config = RecordingStudioUser.config
    @original = {
      password_sign_in_email_limit: @config.password_sign_in_email_limit,
      password_sign_in_ip_limit: @config.password_sign_in_ip_limit,
      password_sign_in_period: @config.password_sign_in_period,
      password_reset_email_limit: @config.password_reset_email_limit,
      password_reset_ip_limit: @config.password_reset_ip_limit,
      password_reset_period: @config.password_reset_period
    }
  end

  teardown do
    Rails.cache = @previous_cache
    @original.each { |setting, value| @config.public_send("#{setting}=", value) }
  end

  test "sign-in email limit blocks the next request and reset stays separate" do
    email = "limit@example.com"
    ip = "203.0.113.20"

    5.times { allow_sign_in!(email, ip) }
    assert_raises(RecordingStudioUser::Services::AuthRateLimiter::RateLimited) do
      allow_sign_in!(email, ip)
    end

    assert_nothing_raised { allow_reset!(email, ip) }
  end

  test "a block on one key does not consume the other" do
    @config.password_sign_in_email_limit = 1
    @config.password_sign_in_ip_limit = 1
    blocked_email = "blocked@example.com"
    fresh_email = "fresh@example.com"
    blocked_ip = "203.0.113.21"
    fresh_ip = "203.0.113.22"

    allow_sign_in!(blocked_email, nil)
    assert_raises(RecordingStudioUser::Services::AuthRateLimiter::RateLimited) do
      allow_sign_in!(blocked_email, fresh_ip)
    end
    assert_nothing_raised { allow_sign_in!(fresh_email, fresh_ip) }

    allow_sign_in!(nil, blocked_ip)
    assert_raises(RecordingStudioUser::Services::AuthRateLimiter::RateLimited) do
      allow_sign_in!("another@example.com", blocked_ip)
    end
    assert_nothing_raised { allow_sign_in!("another@example.com", "203.0.113.23") }
  end

  test "email bucket follows the normalized HMAC and configured period" do
    @config.password_reset_email_limit = 1
    @config.password_reset_period = 2.seconds
    email = "  Person@Example.com "

    allow_reset!(email, nil)
    assert_raises(RecordingStudioUser::Services::AuthRateLimiter::RateLimited) do
      allow_reset!("person@example.com", nil)
    end

    travel 3.seconds
    assert_nothing_raised { allow_reset!("person@example.com", nil) }
  end

  private

  def allow_sign_in!(email, ip)
    RecordingStudioUser::Services::AuthRateLimiter.allow!(action: :sign_in, email: email, ip: ip)
  end

  def allow_reset!(email, ip)
    RecordingStudioUser::Services::AuthRateLimiter.allow!(action: :reset, email: email, ip: ip)
  end
end
