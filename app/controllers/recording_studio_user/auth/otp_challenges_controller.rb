# frozen_string_literal: true

require_dependency RecordingStudioUser::Engine.root.join(
  "app/controllers/concerns/recording_studio_user/auth/signup_terms_acceptance.rb"
).to_s
require_dependency RecordingStudioUser::Engine.root.join(
  "app/controllers/concerns/recording_studio_user/auth/direct_otp.rb"
).to_s
require_dependency RecordingStudioUser::Engine.root.join(
  "app/controllers/concerns/recording_studio_user/auth/inline_otp.rb"
).to_s

module RecordingStudioUser
  module Auth
    # Code-only entry for a sibling gem that already collected an email.
    class OtpChallengesController < BaseController
      include SignupTermsAcceptance
      include DirectOtp
      include InlineOtp

      def show
        @masked_email = masked_auth_email
        return if @masked_email.present?

        redirect_to host_new_user_session_path, alert: start_with_email_alert
      end

      def create
        return render_missing_email if submitted_direct_email.blank?
        return render_throttled if direct_otp_start.throttled?
        return render_inline_otp if inline_otp_request?

        redirect_to otp_direct_challenge_path, notice: generic_login_notice
      end

      def submit
        result = verify_direct_otp
        return render_verify_failure(result) unless result.success?
        return render_inline_signed_in(result) if inline_otp_request?

        finish_direct_otp!(result)
      end

      def resend
        throttled = resend_direct_otp&.throttled?
        return render_inline_resend(throttled) if inline_otp_request?

        if throttled
          redirect_to otp_direct_challenge_path, alert: I18n.t("recording_studio_user.auth.wait_for_code")
        else
          redirect_to otp_direct_challenge_path, notice: generic_login_notice
        end
      end

      private

      def direct_otp_start
        RecordingStudioUser.start_otp_challenge!(
          request: request,
          email: submitted_direct_email,
          return_to: params[:return_to],
          popup: params[:popup]
        )
      end
    end
  end
end
