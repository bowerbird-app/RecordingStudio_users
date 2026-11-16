# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    class SessionsController < BaseController
      include PasswordRateLimit
      include SignInCode

      before_action :require_otp_login_enabled!, only: %i[otp create_otp verify submit_verify resend]

      def new; end

      def continue
        email = submitted_email_from_params
        return render_continue_failure(I18n.t("recording_studio_user.auth.enter_email")) if email.blank?

        store_pending_auth_email!(email)
        continue_with_primary_login!(email)
      end

      def password
        @email = pending_auth_email
        return if @email.present?

        redirect_to host_new_user_session_path, alert: start_with_email_alert
      end

      def create_password
        email = sign_in_params[:email]
        user = resource_class.find_for_database_authentication(email: email)
        unless password_attempt_allowed?(:sign_in, email) && password_sign_in_allowed?(user)
          return render_password_failure(I18n.t("recording_studio_user.auth.email_or_password_mismatch"))
        end

        finish_sign_in!(user)
      end

      def otp; end

      def create_otp
        request_sign_in_code!(submitted_email)
        redirect_to otp_session_verify_path, notice: generic_login_notice
      end

      def send_code
        email = submitted_email.presence || pending_auth_email
        return render_continue_failure(I18n.t("recording_studio_user.auth.enter_email")) if email.blank?

        store_pending_auth_email!(email)
        result = request_sign_in_code!(email)
        redirect_to sign_in_code_path, **sign_in_code_flash(result)
      end

      def verify
        render :verify
      end

      def submit_verify
        result = verify_session_code
        return render_verify_failure(result) unless result.success?
        return finish_password_confirmation!(result.user) if result.challenge.confirmation?
        return render_verify_failure(nil) unless eligible_for_sign_in?(result.user)

        finish_sign_in!(result.user)
      end

      def resend
        user = user_for_otp_resend
        if confirmation_resend?(user)
          RecordingStudioUser.resend_otp!(user: user, purpose: :confirmation, request: request, session: session)
        elsif eligible_for_sign_in?(user)
          RecordingStudioUser.resend_otp!(user: user, purpose: :login, request: request, session: session)
        end
        redirect_to otp_session_verify_path, notice: generic_login_notice
      end

      private

      def continue_with_primary_login!(email)
        return redirect_to otp_session_password_path unless
          RecordingStudioUser.config.primary_login_type_otp?

        require_otp_login_enabled!
        request_sign_in_code!(email)
        redirect_to otp_session_verify_path, notice: generic_login_notice
      end

      def sign_in_params
        params.require(:user).permit(:email, :password, :remember_me)
      end

      def submitted_email
        sign_in_params[:email].to_s.strip.downcase
      end

      def auth_options
        { scope: :user, recall: "#{controller_path}#password" }
      end

      def eligible_for_sign_in?(user)
        user&.confirmed? && user.active_for_authentication?
      end

      def password_sign_in_allowed?(user)
        user&.confirmed? && !user.registered_with_otp? && user.valid_password?(sign_in_params[:password])
      end

      def render_continue_failure(message)
        flash.now[:alert] = message
        render :new, status: :unprocessable_entity
      end

      def render_password_failure(message)
        @email = sign_in_params[:email].to_s.strip.downcase.presence || pending_auth_email
        flash.now[:alert] = message
        render :password, status: :unprocessable_entity
      end

      def render_verify_failure(result)
        flash.now[:alert] = if result
                              verify_failure_message(result.reason)
                            else
                              I18n.t("recording_studio_user.auth.that_code_did_not_work")
                            end
        render :verify, status: :unprocessable_entity
      end
    end
  end
end
