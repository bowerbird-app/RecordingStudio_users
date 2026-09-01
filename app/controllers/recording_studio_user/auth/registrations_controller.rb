# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    class RegistrationsController < BaseController
      EMAIL_TAKEN_MESSAGE = "That email already has an account. Try signing in."

      before_action :require_otp_registration_enabled!, only: %i[otp create_otp verify submit_verify resend]

      def new
        @resource = resource_class.new
      end

      def password
        build_password_resource
        render :password
      end

      def create_password
        build_password_resource(sign_up_params)
        return render_password_taken if otp_account?(submitted_email)
        return render :password, status: :unprocessable_entity unless resource.save

        provision_password_account!
        redirect_to after_sign_up_path_for(resource)
      end

      def otp; end

      def create_otp
        existing = resource_class.find_by(email: submitted_email)
        return redirect_to_sign_in_for(existing) if existing_account_blocks_otp?(existing)

        user = existing || RecordingStudioUser.create_unconfirmed_user!(email: submitted_email)
        RecordingStudioUser.issue_otp!(user: user, purpose: :registration, request: request, session: session)
        redirect_to otp_registration_verify_path
      rescue Services::OtpRateLimiter::RateLimited
        flash.now[:alert] = "Give it a minute, then try again."
        render :otp, status: :too_many_requests
      end

      def verify
        redirect_to host_new_user_registration_path unless session[:otp_challenge_id]
      end

      def submit_verify
        result = RecordingStudioUser.verify_otp!(
          challenge_id: session[:otp_challenge_id],
          code: params[:code],
          purpose: "registration",
          session: session
        )
        return render_verify_failure(result) unless result.success?

        user = RecordingStudioUser.complete_registration!(user: result.user, challenge: result.challenge)
        sign_in_user!(user)
        redirect_to after_sign_up_path_for(user)
      end

      def resend
        issue_registration_resend!
        redirect_to otp_registration_verify_path, notice: "Fresh code on the way."
      rescue Services::OtpRateLimiter::RateLimited
        redirect_to otp_registration_verify_path, alert: "Please wait before requesting another code."
      end

      private

      attr_reader :resource

      def build_password_resource(attrs = {})
        @resource = resource_class.new(attrs)
        @resource.authentication_method = "password" if @resource.respond_to?(:authentication_method=)
      end

      def sign_up_params
        params.require(:user).permit(:email, :password, :password_confirmation)
      end

      def submitted_email
        @submitted_email ||= sign_up_params[:email].to_s.strip.downcase
      end

      def otp_account?(email)
        resource_class.find_by(email: email)&.otp_authentication_method?
      end

      def render_password_taken
        flash.now[:alert] = EMAIL_TAKEN_MESSAGE
        render :password, status: :unprocessable_entity
      end

      def provision_password_account!
        confirm_password_account!
        RecordingStudioUser.record_profile!(resource, actor: resource, **Profile.default_attributes_for(resource))
        sign_in_user!(resource)
      end

      def confirm_password_account!
        return unless RecordingStudioUser.config.password_registration_confirmation == :existing_policy
        return unless resource.password_authentication_method? && resource.confirmed_at.nil?

        resource.update_column(:confirmed_at, Time.current)
      end

      def existing_account_blocks_otp?(existing)
        existing&.confirmed? || existing&.password_authentication_method?
      end

      def redirect_to_sign_in_for(existing)
        flash[existing.confirmed? ? :notice : :alert] = EMAIL_TAKEN_MESSAGE
        redirect_to host_new_user_session_path
      end

      def issue_registration_resend!
        user = user_for_otp_resend
        return unless user&.otp_authentication_method? && !user.confirmed?

        RecordingStudioUser.issue_otp!(
          user: user,
          purpose: :registration,
          request: request,
          session: session,
          rate_limit_scope: :resend
        )
      end

      def render_verify_failure(result)
        flash.now[:alert] = verify_failure_message(result.reason)
        render :verify, status: :unprocessable_entity
      end
    end
  end
end
