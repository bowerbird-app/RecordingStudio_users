# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    # Verify, resend, and failure rendering for the code-only page.
    module DirectOtp
      extend ActiveSupport::Concern

      private

      def submitted_direct_email
        params[:email].to_s.strip.downcase
      end

      def verify_direct_otp
        RecordingStudioUser.verify_otp!(
          challenge_id: session[:otp_challenge_id],
          code: params[:code],
          purpose: session[:otp_purpose].presence || "login",
          session: session
        )
      end

      def finish_direct_otp!(result)
        if registration_challenge?
          finish_registration!(result)
        elsif eligible_for_direct_sign_in?(result.user)
          finish_sign_in!(result.user)
        else
          render_verify_failure(nil)
        end
      end

      def finish_registration!(result)
        user = RecordingStudioUser.complete_registration!(user: result.user, challenge: result.challenge)
        accept_pending_terms_on_signup!(user)
        finish_sign_up!(user)
      end

      def registration_challenge?
        session[:otp_purpose].to_s == "registration"
      end

      def eligible_for_direct_sign_in?(user)
        user&.confirmed? && user.active_for_authentication?
      end

      def resend_direct_otp
        user = user_for_otp_resend
        purpose = session[:otp_purpose].to_s
        return resend_for(user, purpose) if resendable?(user, purpose)

        suppress_resend!
      end

      def resendable?(user, purpose)
        return false if user.blank?

        if purpose == "registration"
          user.registered_with_otp? && !user.confirmed?
        else
          purpose == "login" && eligible_for_direct_sign_in?(user)
        end
      end

      def resend_for(user, purpose)
        RecordingStudioUser.resend_otp!(
          user: user, purpose: purpose, request: request, session: session
        )
      end

      def suppress_resend!
        Services::OtpRateLimiter.allow_requests!(scope: :resend, keys: resend_limit_keys)
        nil
      rescue Services::OtpRateLimiter::RateLimited
        Services::IssueOtp::Result.throttled
      end

      def resend_limit_keys
        [Services::OtpRateLimiter.email_key(pending_auth_email), request.remote_ip].compact_blank
      end

      def render_missing_email
        flash.now[:alert] = I18n.t("recording_studio_user.auth.enter_email")
        render_otp_result(status: :unprocessable_entity)
      end

      def render_throttled
        @masked_email = masked_auth_email
        flash.now[:alert] = I18n.t("recording_studio_user.auth.give_it_a_minute")
        render_otp_result(status: :too_many_requests)
      end

      def render_verify_failure(result)
        @masked_email = masked_auth_email
        flash.now[:alert] = verify_alert(result)
        render_otp_result(status: :unprocessable_entity)
      end

      def render_otp_result(status:)
        return render_inline_otp(status: status) if inline_otp_request?

        render :show, status: status
      end

      def verify_alert(result)
        return I18n.t("recording_studio_user.auth.that_code_did_not_work") unless result

        verify_failure_message(result.reason)
      end

      def masked_auth_email
        OtpCodeForm.mask(pending_auth_email)
      end
    end
  end
end
