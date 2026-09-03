# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    class SessionsController < BaseController
      before_action :require_otp_login_enabled!, only: %i[otp create_otp verify submit_verify resend]

      def new; end

      def password
        render :new
      end

      def create_password
        user = resource_class.find_for_database_authentication(email: sign_in_params[:email])
        return render_password_failure("This account signs in with email codes.") if
          user&.registered_with_otp?
        return render_password_failure("Email or password did not match.") unless
          user&.valid_password?(sign_in_params[:password])

        sign_in_user!(user)
        redirect_to after_sign_in_path_for(user)
      end

      def otp; end

      def create_otp
        user = resource_class.find_by(email: submitted_email)
        issue_login_otp!(user)
        redirect_to otp_session_verify_path, notice: generic_login_notice
      rescue Services::OtpRateLimiter::RateLimited
        redirect_to otp_session_verify_path, notice: generic_login_notice
      end

      def verify
        render :verify
      end

      def submit_verify
        result = RecordingStudioUser.verify_otp!(
          challenge_id: session[:otp_challenge_id],
          code: params[:code],
          purpose: "login",
          session: session
        )
        return render_verify_failure(result) unless result.success?
        return render_verify_failure(nil) unless eligible_for_sign_in?(result.user)

        sign_in_user!(result.user)
        redirect_to after_sign_in_path_for(result.user)
      end

      def resend
        issue_login_otp!(user_for_otp_resend, rate_limit_scope: :resend)
        redirect_to otp_session_verify_path, notice: generic_login_notice
      rescue Services::OtpRateLimiter::RateLimited
        redirect_to otp_session_verify_path, notice: generic_login_notice
      end

      private

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

      def render_password_failure(message)
        flash.now[:alert] = message
        render :new, status: :unprocessable_entity
      end

      def render_verify_failure(result)
        flash.now[:alert] = result ? verify_failure_message(result.reason) : "That code did not work."
        render :verify, status: :unprocessable_entity
      end
    end
  end
end
