# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    module RegistrationOtp
      extend ActiveSupport::Concern

      EMAIL_TAKEN_MESSAGE = "That email already has an account. Try signing in."

      private

      def start_otp_registration!(email)
        existing = resource_class.find_by(email: email)
        return redirect_to_sign_in_for(existing) if existing_account_blocks_otp?(existing)

        user = existing || RecordingStudioUser.create_unconfirmed_user!(email: email)
        RecordingStudioUser.issue_otp!(user: user, purpose: :registration, request: request, session: session)
        redirect_to otp_registration_verify_path
      rescue Services::OtpRateLimiter::RateLimited
        flash.now[:alert] = "Give it a minute, then try again."
        render_otp_rate_limited
      end

      def render_otp_rate_limited
        render action_name == "continue" ? :new : :otp, status: :too_many_requests
      end

      def existing_account_blocks_otp?(existing)
        existing&.confirmed? || existing&.registered_with_password?
      end

      def redirect_to_sign_in_for(existing)
        flash[existing.confirmed? ? :notice : :alert] = EMAIL_TAKEN_MESSAGE
        redirect_to host_new_user_session_path
      end

      def issue_registration_resend!
        user = user_for_otp_resend
        return unless user&.registered_with_otp? && !user.confirmed?

        RecordingStudioUser.issue_otp!(
          user: user,
          purpose: :registration,
          request: request,
          session: session,
          rate_limit_scope: :resend
        )
      end
    end
  end
end
