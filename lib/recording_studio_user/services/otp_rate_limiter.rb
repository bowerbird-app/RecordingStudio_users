# frozen_string_literal: true

require "recording_studio_cache"

module RecordingStudioUser
  module Services
    # Thin adapter: OTP cooldown over {RecordingStudioCache::RateLimiter}.
    #
    # Bucket identity is still +scope+ + +key+ (email / IP / session). The email
    # bucket is not the address. {email_key} is an HMAC-SHA256 of the normalized
    # email, using a key derived from +secret_key_base+, so a cache dump does
    # not list who asked for a code.
    #
    # {allow_requests!} reads every key first. A block on one key raises
    # {RateLimited} and does not consume the others. The increment itself has
    # to be atomic, and the counters have to be shared by every app process.
    # Use Redis or Memcached. A memory store or a null store cannot do that;
    # {warn_unless_shared_store!} logs a warning at boot when one-time codes
    # are on and +Rails.cache+ is one of those stores.
    #
    # Storage uses an +otp:rl+ key segment so legacy boolean +true+ values under
    # +recording_studio_user:otp:#{scope}:#{key}+ are never incremented (that
    # raises +NoMethodError+). Those legacy keys follow the host cooldown (or
    # never expire when cooldown is +nil+).
    #
    # There is no separate cache setting — the store is +Rails.cache+ — and no
    # limit setting. One allow, then cooldown. Odd +cooldown_for+ values follow
    # +expires_in:+ semantics (see +shared_period?+). +fail_closed: true+ only
    # applies when a custom store raises on increment/write into the shared
    # limiter rescue list.
    class OtpRateLimiter
      STORAGE_KEY_PREFIX = "recording_studio_user:otp:rl"
      EMAIL_RATE_LIMIT_SALT = "recording studio otp rate limit email"
      # Main had no limit config; presence of the cooldown key was the one-shot limit.
      LIMIT = 1

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
        list = Array(keys).compact_blank.uniq
        return if list.empty?
        raise RateLimited, scope if list.any? { |key| blocked?(scope, key) }

        list.each { |key| allow_request!(scope: scope, key: key) }
      end

      def self.allow_request!(scope:, key:)
        period = cooldown_for(scope)
        # Shared RateLimiter disables when limit <= 0 and coerces String periods
        # via to_i. Main had no limit and passed cooldown straight to expires_in:.
        return apply_expires_in_cooldown!(scope, key, period) unless shared_period?(period)

        # Boolean left by a prior 0/nil/odd cooldown must RateLimited, not increment.
        raise RateLimited, scope if boolean_cooldown_hit?(scope, key)
        raise RateLimited, scope if rate_limiter_for(scope, key, period).throttle.blocked?
      end

      def self.cooldown_for(scope)
        case scope
        when :resend
          RecordingStudioUser.config.otp_resend_cooldown
        else
          1.minute
        end
      end

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

      def self.warn_unless_shared_store!
        return unless RecordingStudioUser.config.otp_enabled?
        return unless unshared_cache_store?

        Rails.logger.warn(
          "RecordingStudioUser one-time codes need a shared, atomic cache store " \
          "(Redis or Memcached). #{Rails.cache.class.name} cannot enforce OTP rate " \
          "limits across processes."
        )
      end

      def self.unshared_cache_store?
        store = Rails.cache
        store.is_a?(ActiveSupport::Cache::MemoryStore) || store.is_a?(ActiveSupport::Cache::NullStore)
      end
      private_class_method :unshared_cache_store?

      class RateLimited < StandardError
        attr_reader :scope

        def initialize(scope)
          @scope = scope
          super("rate limited")
        end
      end
    end
  end
end
