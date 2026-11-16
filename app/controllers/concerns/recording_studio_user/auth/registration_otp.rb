# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    module RegistrationOtp
      extend ActiveSupport::Concern

      private

      def email_taken_message
        I18n.t("recording_studio_user.auth.signup_did_not_save")
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
        purpose = resend_purpose_for(user)
        return if user.blank? || purpose.blank?

        RecordingStudioUser.resend_otp!(
          user: user,
          purpose: purpose,
          request: request,
          session: session
        )
      end

      def resend_purpose_for(user)
        return if user.blank?

        purpose = session[:otp_purpose].to_s
        return :confirmation if confirmation_resend?(user, purpose)
        return :registration if user.registered_with_otp? && !user.confirmed?

        nil
      end

      def confirmation_resend?(user, purpose)
        purpose == "confirmation" && RecordingStudioUser::PasswordConfirmation.pending?(user)
      end

      def continue_with_primary_registration!(email)
        return redirect_to otp_registration_password_path if
          RecordingStudioUser.config.password_registration_allowed?

        require_otp_registration_enabled!
        start_otp_registration!(email)
      end

      def start_password_confirmation!
        provision_password_account!
        RecordingStudioUser::PasswordConfirmation.mark!(session, resource)
        result = request_confirmation_code!(resource.email)
        redirect_to otp_registration_verify_path, **confirmation_code_flash(result)
      end

      def verify_signup_code
        RecordingStudioUser.verify_otp!(
          challenge_id: session[:otp_challenge_id],
          code: params[:code],
          purpose: signup_code_purpose,
          session: session
        )
      end

      def signup_code_purpose
        purpose = session[:otp_purpose].to_s
        return purpose if %w[registration confirmation].include?(purpose)

        "registration"
      end

      def request_confirmation_code!(email)
        RecordingStudioUser.request_otp!(
          email: email, purpose: :confirmation, request: request, session: session
        )
      end

      def confirmation_code_flash(result)
        if result.throttled?
          { alert: I18n.t("recording_studio_user.auth.wait_for_code") }
        else
          { notice: I18n.t("recording_studio_user.auth.fresh_code") }
        end
      end

      def require_password_registration!
        return if RecordingStudioUser.config.password_registration_allowed?

        raise ActionController::RoutingError, "Not Found"
      end

      def require_signup_code_screen!
        return if RecordingStudioUser.config.password_registration_allowed?
        return if signup_otp_routes_enabled?

        raise ActionController::RoutingError, "OTP registration is not enabled"
      end

      def signup_otp_routes_enabled?
        RecordingStudioUser.config.otp_enabled? && RecordingStudioUser.config.otp_registration_enabled?
      end
    end
  end
end
