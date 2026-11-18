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

      # Unknown, unconfirmed, and code-only emails do the same digest compare as a real password.
      def password_sign_in_allowed?(user)
        candidate = confirmed_password_user(user)
        password_ok = password_matches?(candidate)
        return false unless candidate

        remember_password_result(candidate, password_ok)
      end

      def confirmed_password_user(user)
        user if user&.confirmed? && !user.registered_with_otp?
      end

      def password_matches?(candidate)
        Devise::Encryptor.compare(resource_class, password_digest_for(candidate), sign_in_params[:password])
      end

      def password_digest_for(candidate)
        return candidate.encrypted_password if candidate

        dummy_encrypted_password
      end

      def remember_password_result(candidate, password_ok)
        locked = Services::AccountLockout.locked?(candidate, :password)
        Services::AccountLockout.record_password_failure!(candidate) if locked || !password_ok
        password_ok && !locked
      end

      def dummy_encrypted_password
        ivar = :@dummy_encrypted_password
        self.class.instance_variable_get(ivar) || self.class.instance_variable_set(
          ivar, Devise::Encryptor.digest(RecordingStudioUser.config.user_class, "recording-studio-user-sign-in")
        )
      end
    end
  end
end
