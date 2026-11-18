# frozen_string_literal: true

require "test_helper"
require "tmpdir"

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
    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "user@example.com", type: :session)

    error = assert_raises(RecordingStudioUser::Services::OtpRateLimiter::RateLimited) do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "user@example.com", type: :session)
    end

    assert_equal :issue, error.scope
    assert_equal RecordingStudioUser::RateLimited, error.class
  end

  test "different keys and scopes are independent buckets" do
    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "a@example.com", type: :session)
    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "b@example.com", type: :session)
    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "a@example.com", type: :session)

    assert_raises(RecordingStudioUser::RateLimited) do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "a@example.com", type: :session)
    end
  end

  test "resend cooldown uses otp_resend_cooldown config" do
    RecordingStudioUser.config.otp_resend_cooldown = 2.seconds
    assert_equal 2.seconds, RecordingStudioUser::Services::OtpRateLimiter.cooldown_for(:resend)
    assert_equal 1.minute, RecordingStudioUser::Services::OtpRateLimiter.cooldown_for(:issue)

    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "cooldown@example.com", type: :session)
    assert_raises(RecordingStudioUser::RateLimited) do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "cooldown@example.com", type: :session)
    end

    travel 3.seconds

    assert_nothing_raised do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "cooldown@example.com", type: :session)
    end
  end

  test "stores an integer counter under the otp:rl key and ignores legacy boolean keys" do
    legacy_key = "recording_studio_user:otp:issue:legacy@example.com"
    counter_key = "recording_studio_user:otp:rl:issue:legacy@example.com"
    Rails.cache.write(legacy_key, true, expires_in: 1.minute)

    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "legacy@example.com", type: :session)

    assert_equal true, Rails.cache.read(legacy_key)
    assert_equal 1, Rails.cache.read(counter_key)

    assert_raises(RecordingStudioUser::RateLimited) do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "legacy@example.com", type: :session)
    end
    assert_equal 2, Rails.cache.read(counter_key)
  end

  test "fail_closed blocks only when a custom store raises on increment or write" do
    failing = Object.new
    def failing.increment(*)
      raise Errno::ECONNREFUSED, "cache down"
    end
    def failing.write(*)
      raise Errno::ECONNREFUSED, "cache down"
    end
    def failing.read(*)
      nil
    end

    Rails.cache = failing

    error = assert_raises(RecordingStudioUser::RateLimited) do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "down@example.com", type: :session)
    end
    assert_equal :issue, error.scope
  end

  test "uses Rails.cache as the store like main (not a configurable cache_store)" do
    refute RecordingStudioUser.config.respond_to?(:cache_store)
    refute RecordingStudioUser.config.respond_to?(:cache)

    isolated = ActiveSupport::Cache::MemoryStore.new
    Rails.cache = isolated

    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :issue, key: "store@example.com", type: :session)

    assert_equal 1, isolated.read("recording_studio_user:otp:rl:issue:store@example.com")
    assert_nil @previous_cache.read("recording_studio_user:otp:rl:issue:store@example.com")
  end

  test "limit is always one-shot like main which had no limit config" do
    assert_equal 1, RecordingStudioUser::Services::OtpRateLimiter::LIMIT
    refute RecordingStudioUser.config.respond_to?(:otp_rate_limit)
  end

  # Bypass the positive duration setter the way a bad host ivar could; main passed
  # cooldown_for straight to expires_in: without a limit check.
  test "zero cooldown always allows like main expires_in: 0" do
    RecordingStudioUser.config.instance_variable_set(:@otp_resend_cooldown, 0)

    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "zero@example.com", type: :session)
    assert_nothing_raised do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "zero@example.com", type: :session)
    end
    assert_nil Rails.cache.read("recording_studio_user:otp:rl:resend:zero@example.com")
  end

  test "nil cooldown sticky-blocks after the first allow like main expires_in: nil" do
    RecordingStudioUser.config.instance_variable_set(:@otp_resend_cooldown, nil)

    RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "nil@example.com", type: :session)
    assert_raises(RecordingStudioUser::RateLimited) do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "nil@example.com", type: :session)
    end
    assert_equal true, Rails.cache.read("recording_studio_user:otp:rl:resend:nil@example.com")
  end

  test "negative cooldown raises when raise_on_invalid_cache_expiration_time is on" do
    assert ActiveSupport::Cache::Store.raise_on_invalid_cache_expiration_time
    RecordingStudioUser.config.instance_variable_set(:@otp_resend_cooldown, -1)

    error = assert_raises(ArgumentError) do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "neg@example.com", type: :session)
    end
    assert_match(/cannot be negative/, error.message)
  end

  test "string cooldown raises like main expires_in: String" do
    RecordingStudioUser.config.instance_variable_set(:@otp_resend_cooldown, "60")

    assert_raises(NoMethodError) do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "string@example.com", type: :session)
    end
    assert_nil Rails.cache.read("recording_studio_user:otp:rl:resend:string@example.com")
  end

  test "blank string cooldown raises like main expires_in: blank" do
    RecordingStudioUser.config.instance_variable_set(:@otp_resend_cooldown, "")

    assert_raises(NoMethodError) do
      RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: "blank@example.com", type: :session)
    end
  end

  test "boolean from nil or zero cooldown RateLimits under a positive cooldown without NoMethodError" do
    %w[from-nil@example.com from-zero@example.com].each_with_index do |email, index|
      storage_key = "recording_studio_user:otp:rl:resend:#{email}"

      if index.zero?
        RecordingStudioUser.config.instance_variable_set(:@otp_resend_cooldown, nil)
        RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: email, type: :session)
      else
        Rails.cache.write(storage_key, true, expires_in: 0)
        Rails.cache.write(storage_key, true)
      end
      assert_equal true, Rails.cache.read(storage_key)

      RecordingStudioUser.config.otp_resend_cooldown = 60.seconds

      error = assert_raises(RecordingStudioUser::RateLimited) do
        RecordingStudioUser::Services::OtpRateLimiter.allow_request!(scope: :resend, key: email, type: :session)
      end
      assert_equal :resend, error.scope
      assert_equal true, Rails.cache.read(storage_key)
    end
  end

  test "email key is an hmac of the normalized address and omits the address" do
    limiter = RecordingStudioUser::Services::OtpRateLimiter
    folded = limiter.email_key("  Person@Example.com ")
    plain = limiter.email_key("person@example.com")

    assert_equal plain, folded
    assert_match(/\A[0-9a-f]{64}\z/, plain)
    refute_includes plain, "person@"
    refute_equal plain, limiter.email_key("other@example.com")
  end

  test "a block on one key does not consume the others" do
    limiter = RecordingStudioUser::Services::OtpRateLimiter
    email_key = limiter.email_key("person@example.com")
    ip = "203.0.113.9"
    session_id = "session-9"
    limiter.allow_request!(scope: :issue, key: ip, type: :ip)

    assert_raises(RecordingStudioUser::RateLimited) do
      limiter.allow_requests!(
        scope: :issue,
        keys: [
          limiter.limit_key(:email, email_key),
          limiter.limit_key(:ip, ip),
          limiter.limit_key(:session, session_id)
        ]
      )
    end

    assert_nil Rails.cache.read("recording_studio_user:otp:rl:account:#{email_key}")
    assert_nil Rails.cache.read("recording_studio_user:otp:rl:issue:#{email_key}")
    assert_nil Rails.cache.read("recording_studio_user:otp:rl:issue:#{session_id}")
    assert_equal 1, Rails.cache.read("recording_studio_user:otp:rl:issue:#{ip}")
  end

  test "allow_requests consumes every key only when none is blocked" do
    limiter = RecordingStudioUser::Services::OtpRateLimiter
    email_key = limiter.email_key("open@example.com")
    ip = "203.0.113.10"
    session_id = "session-10"

    limiter.allow_requests!(
      scope: :issue,
      keys: [
        limiter.limit_key(:email, email_key),
        limiter.limit_key(:ip, ip),
        limiter.limit_key(:session, session_id)
      ]
    )

    assert_equal 1, Rails.cache.read("recording_studio_user:otp:rl:account:#{email_key}")
    assert_nil Rails.cache.read("recording_studio_user:otp:rl:issue:#{email_key}")
    assert_equal 1, Rails.cache.read("recording_studio_user:otp:rl:issue:#{ip}")
    assert_equal 1, Rails.cache.read("recording_studio_user:otp:rl:issue:#{session_id}")
  end

  test "send and resend share the account email bucket and keep ip scopes apart" do
    limiter = RecordingStudioUser::Services::OtpRateLimiter
    email_key = limiter.email_key("shared@example.com")
    ip = "203.0.113.40"

    limiter.allow_request!(scope: :issue, key: email_key, type: :email)
    assert_raises(RecordingStudioUser::RateLimited) do
      limiter.allow_request!(scope: :resend, key: email_key, type: :email)
    end
    assert Rails.cache.read("recording_studio_user:otp:rl:account:#{email_key}").to_i.positive?
    assert_nil Rails.cache.read("recording_studio_user:otp:rl:issue:#{email_key}")
    assert_nil Rails.cache.read("recording_studio_user:otp:rl:resend:#{email_key}")

    limiter.allow_request!(scope: :issue, key: ip, type: :ip)
    assert_nothing_raised { limiter.allow_request!(scope: :resend, key: ip, type: :ip) }
  end

  test "the account bucket follows otp_resend_cooldown" do
    RecordingStudioUser.config.otp_resend_cooldown = 2.seconds
    limiter = RecordingStudioUser::Services::OtpRateLimiter
    email_key = limiter.email_key("account-cooldown@example.com")

    assert_equal 2.seconds, limiter.cooldown_for(:account)
    assert_equal 1.minute, limiter.cooldown_for(:issue)

    limiter.allow_request!(scope: :issue, key: email_key, type: :email)
    assert_raises(RecordingStudioUser::RateLimited) do
      limiter.allow_request!(scope: :resend, key: email_key, type: :email)
    end

    travel 3.seconds

    assert_nothing_raised do
      limiter.allow_request!(scope: :resend, key: email_key, type: :email)
    end
  end

  test "key type is explicit and a 64-hex value is not an email key" do
    limiter = RecordingStudioUser::Services::OtpRateLimiter
    email_key = limiter.email_key("typed@example.com")
    hex_ip = "ab" * 32
    session_id = "session-typed"

    limiter.allow_requests!(
      scope: :issue,
      keys: [
        limiter.limit_key(:email, email_key),
        limiter.limit_key(:ip, hex_ip),
        limiter.limit_key(:session, session_id)
      ]
    )

    assert_equal 1, Rails.cache.read("recording_studio_user:otp:rl:account:#{email_key}")
    assert_equal 1, Rails.cache.read("recording_studio_user:otp:rl:issue:#{hex_ip}")
    assert_equal 1, Rails.cache.read("recording_studio_user:otp:rl:issue:#{session_id}")
    assert_nil Rails.cache.read("recording_studio_user:otp:rl:account:#{hex_ip}")
    assert_raises(ArgumentError) { limiter.limit_key(:user, "x") }
  end

  test "warns in development and test and raises elsewhere for an unshared store" do
    previous_logger = Rails.logger
    io = StringIO.new
    Rails.logger = Logger.new(io)

    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioUser::Services::OtpRateLimiter.require_shared_store!
    assert_match(/shared, atomic cache store/, io.string)
    assert_match(/MemoryStore/, io.string)

    io.truncate(0)
    io.rewind
    Rails.cache = ActiveSupport::Cache::NullStore.new
    RecordingStudioUser::Services::OtpRateLimiter.require_shared_store!
    assert_match(/NullStore/, io.string)

    io.truncate(0)
    io.rewind
    Rails.cache = quiet_cache_store
    RecordingStudioUser::Services::OtpRateLimiter.require_shared_store!
    RecordingStudioUser::Services::AuthRateLimiter.require_shared_store!
    assert_empty io.string

    Dir.mktmpdir do |dir|
      Rails.cache = ActiveSupport::Cache::FileStore.new(dir)
      RecordingStudioUser::Services::OtpRateLimiter.require_shared_store!
      assert_match(/FileStore/, io.string)
    end

    RecordingStudioUser.config.otp_enabled = false
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    io.truncate(0)
    io.rewind
    RecordingStudioUser::Services::OtpRateLimiter.require_shared_store!
    assert_empty io.string

    RecordingStudioUser.config.otp_enabled = true
    with_env("staging") do
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      error = assert_raises(RuntimeError) do
        RecordingStudioUser::Services::OtpRateLimiter.require_shared_store!
      end
      assert_match(/MemoryStore/, error.message)
      assert_raises(RuntimeError) { RecordingStudioUser::Services::AuthRateLimiter.require_shared_store! }

      Rails.cache = ActiveSupport::Cache::NullStore.new
      assert_raises(RuntimeError) { RecordingStudioUser::Services::OtpRateLimiter.require_shared_store! }
      assert_raises(RuntimeError) { RecordingStudioUser::Services::AuthRateLimiter.require_shared_store! }

      Dir.mktmpdir do |dir|
        Rails.cache = ActiveSupport::Cache::FileStore.new(dir)
        assert_raises(RuntimeError) { RecordingStudioUser::Services::OtpRateLimiter.require_shared_store! }
        file_error = assert_raises(RuntimeError) do
          RecordingStudioUser::Services::AuthRateLimiter.require_shared_store!
        end
        assert_match(/FileStore/, file_error.message)
      end

      RecordingStudioUser.config.otp_enabled = false
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      assert_nothing_raised { RecordingStudioUser::Services::OtpRateLimiter.require_shared_store! }
      assert_raises(RuntimeError) { RecordingStudioUser::Services::AuthRateLimiter.require_shared_store! }
    end
  ensure
    RecordingStudioUser.config.otp_enabled = true
    Rails.logger = previous_logger
  end

  def with_env(name)
    singleton = class << Rails; self; end
    original = Rails.method(:env)
    singleton.define_method(:env) { ActiveSupport::StringInquirer.new(name) }
    yield
  ensure
    singleton.define_method(:env) { original.call }
  end

  def quiet_cache_store
    store_class = Class.new(ActiveSupport::Cache::Store) do
      def read(*)
        nil
      end

      def write(*)
        nil
      end
    end
    store_class.new
  end
end
