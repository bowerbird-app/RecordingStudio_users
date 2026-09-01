# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    class SessionsController < BaseController
      before_action :require_otp_login_enabled!, only: %i[otp create_otp verify submit_verify resend]

      def new; end

      def password
        render :password
      end

      def create_password
        user = resource_class.find_for_database_authentication(email: sign_in_params[:email])
        if user&.otp_authentication_method?
          flash.now[:alert] = "This account signs in with email codes. Use the Email OTP tab."
          return render :password, status: :unprocessable_entity
        end

        if user&.valid_password?(sign_in_params[:password])
          sign_in_user!(user)
          redirect_to after_sign_in_path_for(user)
        else
          flash.now[:alert] = "Email or password did not match."
          render :password, status: :unprocessable_entity
        end
      end

      def otp
      end

      def create_otp
        email = sign_in_params[:email].to_s.strip.downcase
        user = resource_class.find_by(email: email)
        if user&.otp_authentication_method? && user.confirmed? && user.active_for_authentication?
          RecordingStudioUser.issue_otp!(user: user, purpose: :login, request: request, session: session)
        end
        redirect_to otp_session_verify_path, notice: generic_login_notice
      rescue Services::OtpRateLimiter::RateLimited
        redirect_to otp_session_verify_path, notice: generic_login_notice
      end

      def verify
        redirect_to host_new_user_session_path unless session[:otp_challenge_id]
      end

      def submit_verify
        result = RecordingStudioUser.verify_otp!(
          challenge_id: session[:otp_challenge_id],
          code: params[:code],
          purpose: "login",
          session: session
        )

        unless result.success?
          flash.now[:alert] = verify_failure_message(result.reason)
          return render :verify, status: :unprocessable_entity
        end

        user = result.user
        unless user.active_for_authentication? && user.otp_authentication_method?
          flash.now[:alert] = "That code did not work."
          return render :verify, status: :unprocessable_entity
        end

        sign_in_user!(user)
        redirect_to after_sign_in_path_for(user)
      end

      def resend
        user = user_for_otp_resend
        if user&.otp_authentication_method? && user.confirmed? && user.active_for_authentication?
          RecordingStudioUser.issue_otp!(
            user: user,
            purpose: :login,
            request: request,
            session: session,
            rate_limit_scope: :resend
          )
        end
        redirect_to otp_session_verify_path, notice: generic_login_notice
      rescue Services::OtpRateLimiter::RateLimited
        redirect_to otp_session_verify_path, notice: generic_login_notice
      end

      private

      def resource_class
        RecordingStudioUser.config.user_class
      end

      def sign_in_params
        params.require(:user).permit(:email, :password, :remember_me)
      end

      def auth_options
        { scope: :user, recall: "#{controller_path}#password" }
      end

      def verify_failure_message(reason)
        {
          invalid_code: "That code did not work. Try again.",
          expired: "That code expired. Request a new one.",
          consumed: "That code was already used.",
          revoked: "That code is no longer valid.",
          too_many_attempts: "Too many tries. Request a new code.",
          session_mismatch: "Start over with a new code."
        }.fetch(reason, "That code did not work.")
      end
    end
  end
end
