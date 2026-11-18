# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    module SignInCode
      extend ActiveSupport::Concern

      def sign_in_link
        @sign_in_token = params[:sign_in_token].to_s
        @masked_email = RecordingStudioUser::OtpCodeForm.mask(pending_sign_in_link_user&.email)
        @sign_in_token = nil if @masked_email.blank?
        render :sign_in_link
      end

      def submit_sign_in_link
        user = RecordingStudioUser::SignInLink.authenticate!(params[:sign_in_token])
        return render :sign_in_link, status: :unprocessable_entity unless user

        Services::AccountLockout.reset_otp!(user)
        Services::AccountLockout.reset_password!(user)
        finish_sign_in!(user)
      end

      private

      def pending_sign_in_link_user
        RecordingStudioUser::SignInLink.pending_user(@sign_in_token)
      end

      def verify_session_code
        RecordingStudioUser.verify_otp!(
          challenge_id: session[:otp_challenge_id],
          code: params[:code],
          purpose: session[:otp_purpose].presence || "login",
          session: session
        )
      end

      def request_sign_in_code!(email)
        purpose = sign_in_code_purpose(email)
        return suppressed_sign_in_code if purpose.blank?

        RecordingStudioUser.request_otp!(
          email: email, purpose: purpose, request: request, session: session
        )
      end

      def suppressed_sign_in_code
        clear_otp_challenge_session!
        RecordingStudioUser::Services::IssueOtp::Result.suppressed
      end

      def sign_in_code_purpose(email)
        user = resource_class.find_for_database_authentication(email: email.to_s.strip.downcase)
        return :confirmation if RecordingStudioUser::PasswordConfirmation.pending?(user)
        return :registration if unconfirmed_otp_registration?(user)
        return :login if RecordingStudioUser.config.otp_enabled? && RecordingStudioUser.config.otp_login_enabled?

        nil
      end

      def unconfirmed_otp_registration?(user)
        user.present? &&
          user.respond_to?(:registered_with_otp?) && user.registered_with_otp? &&
          !user.confirmed? &&
          RecordingStudioUser.config.otp_enabled? &&
          RecordingStudioUser.config.otp_registration_enabled?
      end

      def clear_otp_challenge_session!
        return unless session

        session.delete(:otp_challenge_id)
        session.delete(:otp_purpose)
        session.delete(:otp_user_id)
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
