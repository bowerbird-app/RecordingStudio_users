# frozen_string_literal: true

require "recording_studio_cache"

module RecordingStudioUser
  module Services
    # Thin adapter: OTP cooldown over {RecordingStudioCache::RateLimiter}.
    #
    # Bucket identity is still +scope+ + +key+ (email / IP / session). Storage uses
    # a new +otp:rl+ key segment so legacy boolean +true+ values under
    # +recording_studio_user:otp:#{scope}:#{key}+ are never incremented (that
    # raises +NoMethodError+). Those legacy keys expire within one cooldown
    # (≤ 1 minute).
    #
    # Main always used +Rails.cache+ (no configurable store) and had no limit
    # setting — one allow, then cooldown. This adapter always passes +limit: 1+
    # and +store: Rails.cache+. Cooldown lengths, +RateLimited+, and public
    # config stay the same; odd +cooldown_for+ values follow main's
    # +expires_in:+ semantics (see +shared_period?+).
    class OtpRateLimiter
      STORAGE_KEY_PREFIX = "recording_studio_user:otp:rl"
      # Main had no limit config; presence of the cooldown key was the one-shot limit.
      LIMIT = 1

      def self.allow_request!(scope:, key:)
        period = cooldown_for(scope)
        # Shared RateLimiter disables when limit <= 0 and coerces String periods
        # via to_i. Main had no limit and passed cooldown straight to expires_in:.
        return apply_expires_in_cooldown!(scope, key, period) unless shared_period?(period)

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
      # limiter would mishandle (0 ⇒ always allow; negative/nil ⇒ sticky block;
      # String ⇒ NoMethodError from expires_in:).
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
