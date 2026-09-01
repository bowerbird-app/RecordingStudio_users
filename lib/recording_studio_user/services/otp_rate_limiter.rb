# frozen_string_literal: true

module RecordingStudioUser
  module Services
    class OtpRateLimiter
      def self.allow_request!(scope:, key:)
        cache_key = "recording_studio_user:otp:#{scope}:#{key}"
        raise RateLimited, scope if Rails.cache.read(cache_key)

        Rails.cache.write(cache_key, true, expires_in: cooldown_for(scope))
      end

      def self.cooldown_for(scope)
        case scope
        when :resend
          RecordingStudioUser.config.otp_resend_cooldown
        else
          1.minute
        end
      end

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
