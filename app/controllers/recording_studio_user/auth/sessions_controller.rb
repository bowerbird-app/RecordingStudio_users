# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    class SessionsController < BaseController
      before_action :require_otp_login_enabled!, only: %i[otp create_otp verify submit_verify resend]

      def new; end

      def continue
        email = submitted_email_from_params
        return render_continue_failure("Enter your email to continue.") if email.blank?

        store_pending_auth_email!(email)
        continue_with_primary_login!(email)
      rescue Services::OtpRateLimiter::RateLimited
        redirect_to otp_session_verify_path, notice: generic_login_notice
      end

      def password
        @email = pending_auth_email
        redirect_to host_new_user_session_path, alert: "Start with your email." if @email.blank?
      end

      def create_password
        user = resource_class.find_for_database_authentication(email: sign_in_params[:email])
        return render_password_failure("This account signs in with email codes.") if
          user&.registered_with_otp?
        return render_password_failure("Email or password did not match.") unless
          user&.valid_password?(sign_in_params[:password])

        finish_sign_in!(user)
      end

      def otp; end

      def create_otp
        issue_login_otp!(resource_class.find_by(email: submitted_email))
        redirect_to otp_session_verify_path, notice: generic_login_notice
      rescue Services::OtpRateLimiter::RateLimited
        redirect_to otp_session_verify_path, notice: generic_login_notice
      end

      def verify
        render :verify
      end

      def submit_verify
        result = verify_login_otp
        return render_verify_failure(result) unless result.success?
        return render_verify_failure(nil) unless eligible_for_sign_in?(result.user)

        finish_sign_in!(result.user)
      end

      def resend
        issue_login_otp!(user_for_otp_resend, rate_limit_scope: :resend)
        redirect_to otp_session_verify_path, notice: generic_login_notice
      rescue Services::OtpRateLimiter::RateLimited
        redirect_to otp_session_verify_path, notice: generic_login_notice
      end

      private

      def continue_with_primary_login!(email)
        return redirect_to otp_session_password_path unless
          RecordingStudioUser.config.primary_login_type_otp?

        require_otp_login_enabled!
        issue_login_otp!(resource_class.find_by(email: email))
        redirect_to otp_session_verify_path, notice: generic_login_notice
      end

      def verify_login_otp
        RecordingStudioUser.verify_otp!(
          challenge_id: session[:otp_challenge_id],
          code: params[:code],
          purpose: "login",
          session: session
        )
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

      def issue_login_otp!(user, rate_limit_scope: :issue)
        return unless eligible_for_sign_in?(user)

        RecordingStudioUser.issue_otp!(
          user: user,
          purpose: :login,
          request: request,
          session: session,
          rate_limit_scope: rate_limit_scope
        )
      end

      # Password accounts can request a login code too. Having a password is a
      # capability, not a restriction on how you sign in.
      def eligible_for_sign_in?(user)
        user&.confirmed? && user.active_for_authentication?
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
        flash.now[:alert] = result ? verify_failure_message(result.reason) : "That code did not work."
        render :verify, status: :unprocessable_entity
      end
    end
  end
end
