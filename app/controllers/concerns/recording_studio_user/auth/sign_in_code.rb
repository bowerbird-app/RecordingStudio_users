# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    module SignInCode
      extend ActiveSupport::Concern

      private

      def verify_session_code
        RecordingStudioUser.verify_otp!(
          challenge_id: session[:otp_challenge_id],
          code: params[:code],
          purpose: session[:otp_purpose].presence || "login",
          session: session
        )
      end

      def request_sign_in_code!(email)
        RecordingStudioUser.request_otp!(
          email: email,
          purpose: sign_in_code_purpose(email),
          request: request,
          session: session
        )
      end

      def sign_in_code_purpose(email)
        user = resource_class.find_for_database_authentication(email: email.to_s.strip.downcase)
        return :confirmation if RecordingStudioUser::PasswordConfirmation.pending?(user)

        :login
      end

      def sign_in_code_path
        if RecordingStudioUser.config.otp_enabled? && RecordingStudioUser.config.otp_login_enabled?
          otp_session_verify_path
        else
          otp_registration_verify_path
        end
      end

      def sign_in_code_flash(result)
        if result.throttled?
          { alert: I18n.t("recording_studio_user.auth.wait_for_code") }
        else
          { notice: generic_login_notice }
        end
      end

      def confirmation_resend?(user)
        confirming = session[:otp_purpose].to_s == "confirmation"
        confirming && RecordingStudioUser::PasswordConfirmation.pending?(user)
      end
    end
  end
end
