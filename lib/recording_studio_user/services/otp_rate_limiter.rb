# frozen_string_literal: true

require "recording_studio_cache"

module RecordingStudioUser
  module Services
    # OTP cooldown over {RecordingStudioCache::RateLimiter}.
    #
    # Callers pass each key as :email, :ip, or :session. An email key is an
    # HMAC of the address (not the address) and is stored under +:account+ for
    # send and resend, using +otp_resend_cooldown+. IP and session keys keep
    # the caller's scope. {allow_requests!} reads every key before consuming
    # any of them. Counters must be shared: Redis or Memcached. A memory, null,
    # or file store raises at boot outside development and test when codes are
    # on. Password limits use the same check. Development and test warn.
    # Odd +cooldown_for+ values follow +expires_in:+. Storage uses +otp:rl+ so
    # a legacy boolean value is not incremented.
    class OtpRateLimiter
      STORAGE_KEY_PREFIX = "recording_studio_user:otp:rl"
      EMAIL_RATE_LIMIT_SALT = "recording studio otp rate limit email"
      # Shared by send and resend so a reissue cannot double the per-account rate.
      ACCOUNT_SCOPE = :account
      KEY_TYPES = %i[email ip session].freeze
      # Main had no limit config; presence of the cooldown key was the one-shot limit.
      LIMIT = 1

      def self.limit_key(type, value)
        return if value.blank?

        type = type.to_sym
        raise ArgumentError, "key type must be email, ip, or session" unless KEY_TYPES.include?(type)

        { type: type, value: value.to_s }
      end

      def self.normalize_email(email)
        email.to_s.strip.downcase
      end

      # HMAC-SHA256 of the normalized email. The HMAC key comes from
      # +secret_key_base+ via +ActiveSupport::KeyGenerator+.
      def self.email_key(email)
        OpenSSL::HMAC.hexdigest("SHA256", email_rate_limit_key, normalize_email(email))
      end

      # Check every key. Consume them only when none is already blocked.
      def self.allow_requests!(scope:, keys:)
        list = Array(keys).filter_map { |key| normalize_key(key) }.uniq
        return if list.empty?
        raise RateLimited, scope if list.any? { |key| blocked?(bucket_for(scope, key), key[:value]) }

        list.each { |key| allow_request!(scope: scope, key: key[:value], type: key[:type]) }
      end

      def self.allow_request!(scope:, key:, type:)
        typed = limit_key(type, key)
        return if typed.nil?

        bucket = bucket_for(scope, typed)
        period = cooldown_for(bucket)
        # Shared RateLimiter disables when limit <= 0 and coerces String periods
        # via to_i. Main had no limit and passed cooldown straight to expires_in:.
        return apply_expires_in_cooldown!(bucket, typed[:value], period) unless shared_period?(period)

        # Boolean left by a prior 0/nil/odd cooldown must RateLimited, not increment.
        raise RateLimited, scope if boolean_cooldown_hit?(bucket, typed[:value])
        raise RateLimited, scope if rate_limiter_for(bucket, typed[:value], period).throttle.blocked?
      end

      def self.cooldown_for(scope)
        case scope
        when :resend, ACCOUNT_SCOPE
          RecordingStudioUser.config.otp_resend_cooldown
        else
          1.minute
        end
      end

      def self.normalize_key(key)
        return if key.blank?
        raise ArgumentError, "rate limit key must include a type" unless key.is_a?(Hash)

        limit_key(key[:type] || key["type"], key[:value] || key["value"])
      end
      private_class_method :normalize_key

      # Email keys share one bucket. IP and session keys keep the caller's scope.
      def self.bucket_for(scope, key)
        key[:type] == :email ? ACCOUNT_SCOPE : scope
      end
      private_class_method :bucket_for

      # Positive Numeric (including ActiveSupport::Duration) only — same values
      # main could pass to expires_in: without error and with a lasting TTL.
      def self.shared_period?(period)
        period.is_a?(Numeric) && period.to_i.positive?
      end
      private_class_method :shared_period?

      # Reproduce main's read-then-write(true, expires_in:) for values the shared
      # limiter would mishandle (0 ⇒ always allow; nil ⇒ sticky block;
      # String ⇒ NoMethodError from expires_in:; negative raises only when
      # +raise_on_invalid_cache_expiration_time+ is on).
      def self.apply_expires_in_cooldown!(scope, key, period)
        storage_key = storage_key_for(scope, key)
        raise RateLimited, scope if Rails.cache.read(storage_key)

        Rails.cache.write(storage_key, true, expires_in: period)
      end
      private_class_method :apply_expires_in_cooldown!

      def self.boolean_cooldown_hit?(scope, key)
        Rails.cache.read(storage_key_for(scope, key)) == true
      end
      private_class_method :boolean_cooldown_hit?

      def self.rate_limiter_for(scope, key, period)
        RecordingStudioCache::RateLimiter.new(
          key: "#{scope}:#{key}",
          prefix: STORAGE_KEY_PREFIX,
          limit: LIMIT,
          period: period,
          backend: :rails_cache,
          strategy: :ttl,
          store: Rails.cache,
          fail_closed: true
        )
      end
      private_class_method :rate_limiter_for

      def self.storage_key_for(scope, key)
        "#{STORAGE_KEY_PREFIX}:#{scope}:#{key}"
      end
      private_class_method :storage_key_for

      def self.blocked?(scope, key)
        value = Rails.cache.read(storage_key_for(scope, key))
        return true if value == true
        return true if value.is_a?(Numeric) && value >= LIMIT

        false
      end
      private_class_method :blocked?

      def self.email_rate_limit_key
        ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
          EMAIL_RATE_LIMIT_SALT, 32
        )
      end
      private_class_method :email_rate_limit_key

      def self.require_shared_store!
        SharedCacheStore.enforce_otp!
      end

      class RateLimited < StandardError
        attr_reader :scope

        def initialize(scope)
          @scope = scope
          super("rate limited")
        end
      end
    end

    # Memory, null, and file stores cannot share a limit across hosts.
    module SharedCacheStore
      module_function

      def enforce_otp!
        return unless RecordingStudioUser.config.otp_enabled?

        enforce!(
          "RecordingStudioUser one-time codes need a shared, atomic cache store " \
          "(Redis or Memcached). #{Rails.cache.class.name} cannot enforce OTP rate " \
          "limits across processes."
        )
      end

      def enforce!(message)
        return unless unshared?
        raise message unless Rails.env.development? || Rails.env.test?

        Rails.logger.warn(message)
      end

      def unshared?
        store = Rails.cache
        store.is_a?(ActiveSupport::Cache::MemoryStore) ||
          store.is_a?(ActiveSupport::Cache::NullStore) ||
          store.is_a?(ActiveSupport::Cache::FileStore)
      end
    end
  end
end
