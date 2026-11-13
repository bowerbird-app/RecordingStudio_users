# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    # Counts a password sign-in or reset before the action does its work.
    # A spent limit returns false and does not say why.
    module PasswordRateLimit
      private

      def password_attempt_allowed?(action, email)
        Services::AuthRateLimiter.allow!(action: action, email: email, ip: request.remote_ip)
        true
      rescue Services::AuthRateLimiter::RateLimited
        false
      end
    end
  end
end
