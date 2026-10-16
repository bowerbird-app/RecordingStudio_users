# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    module RegistrationOtp
      extend ActiveSupport::Concern

      private

      def email_taken_message
        I18n.t("recording_studio_user.auth.email_taken")
      end

      # Unknown, existing, disabled, and password-registered addresses all land
      # on the same check-email page. A throttled request creates nothing.
      def start_otp_registration!(email)
        result = request_registration_code(email)
        return render_throttled_registration if result.throttled?

        redirect_to otp_registration_verify_path
      end

      def request_registration_code(email)
        RecordingStudioUser.request_otp!(
          email: email, purpose: :registration, request: request, session: session
        )
      end

      def render_throttled_registration
        flash.now[:alert] = I18n.t("recording_studio_user.auth.give_it_a_minute")
        render_otp_rate_limited
      end

      def render_otp_rate_limited
        render action_name == "continue" ? :new : :otp, status: :too_many_requests
      end

      def issue_registration_resend!
        user = user_for_otp_resend
        return unless user&.registered_with_otp? && !user.confirmed?

        RecordingStudioUser.resend_otp!(
          user: user,
          purpose: :registration,
          request: request,
          session: session
        )
      end
    end
  end
end
