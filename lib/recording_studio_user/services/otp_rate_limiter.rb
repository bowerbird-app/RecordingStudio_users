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
    # (≤ 1 minute). Cooldown lengths, +RateLimited+, and public config are unchanged.
    class OtpRateLimiter
      STORAGE_KEY_PREFIX = "recording_studio_user:otp:rl"

      def self.allow_request!(scope:, key:)
        raise RateLimited, scope if rate_limiter_for(scope, key).throttle.blocked?
      end

      def self.cooldown_for(scope)
        case scope
        when :resend
          RecordingStudioUser.config.otp_resend_cooldown
        else
          1.minute
        end
      end

      def self.rate_limiter_for(scope, key)
        RecordingStudioCache::RateLimiter.new(
          key: "#{scope}:#{key}",
          prefix: STORAGE_KEY_PREFIX,
          limit: 1,
          period: cooldown_for(scope),
          backend: :rails_cache,
          strategy: :ttl,
          store: Rails.cache,
          fail_closed: true
        )
      end
      private_class_method :rate_limiter_for

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
