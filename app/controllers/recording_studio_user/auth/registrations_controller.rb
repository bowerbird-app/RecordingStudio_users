# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    class RegistrationsController < BaseController
      def new
        @resource = resource_class.new
      end

      def password
        build_password_resource
        render :password
      end

      def create_password
        build_password_resource(sign_up_params)
        if resource.save
          if password_registration_confirms_immediately?
            resource.skip_confirmation! if resource.respond_to?(:skip_confirmation!) && resource.respond_to?(:confirmed?) && !resource.confirmed?
          end
          RecordingStudioUser.record_profile!(resource, actor: resource)
          sign_in_user!(resource)
          redirect_to after_sign_up_path_for(resource)
        else
          render :password, status: :unprocessable_entity
        end
      end

      def otp
      end

      def create_otp
        email = sign_up_params[:email].to_s.strip.downcase
        existing = resource_class.find_by(email: email)

        if existing&.confirmed?
          flash[:notice] = "That email already has an account. Try signing in."
          redirect_to new_user_session_path and return
        end

        if existing&.password_authentication_method?
          flash[:alert] = "That email already has an account. Try signing in."
          redirect_to new_user_session_path and return
        end

        user = existing || RecordingStudioUser.create_unconfirmed_user!(email: email)
        RecordingStudioUser.issue_otp!(user: user, purpose: :registration, request: request, session: session)
        redirect_to otp_registration_verify_path
      rescue Services::OtpRateLimiter::RateLimited
        flash.now[:alert] = "Give it a minute, then try again."
        render :otp, status: :too_many_requests
      end

      def verify
        redirect_to new_user_registration_path unless session[:otp_challenge_id]
      end

      def submit_verify
        result = RecordingStudioUser.verify_otp!(
          challenge_id: session[:otp_challenge_id],
          code: params[:code],
          purpose: "registration",
          session: session
        )

        unless result.success?
          flash.now[:alert] = verify_failure_message(result.reason)
          return render :verify, status: :unprocessable_entity
        end

        user = RecordingStudioUser.complete_registration!(user: result.user, challenge: result.challenge)
        sign_in_user!(user)
        redirect_to after_sign_up_path_for(user)
      end

      def resend
        user = resource_class.find_by(id: session[:otp_user_id]) ||
               resource_class.find_by(email: session[:otp_email])
        if user&.otp_authentication_method? && !user.confirmed?
          RecordingStudioUser.issue_otp!(user: user, purpose: :registration, request: request, session: session)
        end
        redirect_to otp_registration_verify_path, notice: "Fresh code on the way."
      rescue Services::OtpRateLimiter::RateLimited
        redirect_to otp_registration_verify_path, alert: "Please wait before requesting another code."
      end

      private

      def resource_class
        RecordingStudioUser.config.user_class
      end

      def resource
        @resource
      end

      def build_password_resource(attrs = {})
        @resource = resource_class.new(attrs)
        @resource.authentication_method = "password" if @resource.respond_to?(:authentication_method=)
      end

      def sign_up_params
        params.require(:user).permit(:email, :password, :password_confirmation)
      end

      def password_registration_confirms_immediately?
        RecordingStudioUser.config.password_registration_confirmation == :existing_policy
      end

      def after_sign_up_path_for(_resource)
        main_app.root_path
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
