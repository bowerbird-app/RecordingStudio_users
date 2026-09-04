# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    class RegistrationsController < BaseController
      EMAIL_TAKEN_MESSAGE = "That email already has an account. Try signing in."
      AUTH_EMAIL_KEY = :auth_email

      before_action :require_otp_registration_enabled!, only: %i[otp create_otp verify submit_verify resend]

      def new
        @resource = resource_class.new
      end

      def continue
        email = submitted_email_from_params
        return render_continue_failure("Enter your email to continue.") if email.blank?

        session[AUTH_EMAIL_KEY] = email

        if RecordingStudioUser.config.primary_login_type_otp?
          require_otp_registration_enabled!
          start_otp_registration!(email)
        else
          redirect_to otp_registration_password_path
        end
      end

      def password
        email = pending_auth_email
        return redirect_to host_new_user_registration_path, alert: "Start with your email." if email.blank?

        build_password_resource(email: email)
      end

      def create_password
        build_password_resource(sign_up_params)
        return render_password_taken if otp_account?(submitted_email)
        return render_password_failure unless resource.save

        clear_pending_auth_email!
        provision_password_account!
        redirect_to after_sign_up_path_for(resource)
      end

      def otp; end

      def create_otp
        start_otp_registration!(submitted_email)
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

        clear_pending_auth_email!
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
        @resource.registered_with = "password" if @resource.respond_to?(:registered_with=)
      end

      def sign_up_params
        params.require(:user).permit(:email, :password, :password_confirmation)
      end

      def submitted_email
        @submitted_email ||= sign_up_params[:email].to_s.strip.downcase
      end

      def submitted_email_from_params
        params.dig(:user, :email).to_s.strip.downcase
      end

      def pending_auth_email
        session[AUTH_EMAIL_KEY].presence || submitted_email_from_params.presence
      end

      def clear_pending_auth_email!
        session.delete(AUTH_EMAIL_KEY)
      end

      def start_otp_registration!(email)
        existing = resource_class.find_by(email: email)
        return redirect_to_sign_in_for(existing) if existing_account_blocks_otp?(existing)

        user = existing || RecordingStudioUser.create_unconfirmed_user!(email: email)
        RecordingStudioUser.issue_otp!(user: user, purpose: :registration, request: request, session: session)
        redirect_to otp_registration_verify_path
      rescue Services::OtpRateLimiter::RateLimited
        flash.now[:alert] = "Give it a minute, then try again."
        render_otp_rate_limited
      end

      def render_otp_rate_limited
        if action_name == "continue"
          render :new, status: :too_many_requests
        else
          render :otp, status: :too_many_requests
        end
      end

      def otp_account?(email)
        resource_class.find_by(email: email)&.registered_with_otp?
      end

      def render_continue_failure(message)
        @resource = resource_class.new(email: submitted_email_from_params)
        flash.now[:alert] = message
        render :new, status: :unprocessable_entity
      end

      def render_password_taken
        flash.now[:alert] = EMAIL_TAKEN_MESSAGE
        render :password, status: :unprocessable_entity
      end

      def render_password_failure
        render :password, status: :unprocessable_entity
      end

      def provision_password_account!
        confirm_password_account!
        RecordingStudioUser.record_profile!(resource, actor: resource, **Profile.default_attributes_for(resource))
        sign_in_user!(resource)
      end

      def confirm_password_account!
        return unless RecordingStudioUser.config.password_registration_confirmation == :existing_policy
        return unless resource.registered_with_password? && resource.confirmed_at.nil?

        resource.update_column(:confirmed_at, Time.current)
      end

      def existing_account_blocks_otp?(existing)
        existing&.confirmed? || existing&.registered_with_password?
      end

      def redirect_to_sign_in_for(existing)
        flash[existing.confirmed? ? :notice : :alert] = EMAIL_TAKEN_MESSAGE
        redirect_to host_new_user_session_path
      end

      def issue_registration_resend!
        user = user_for_otp_resend
        return unless user&.registered_with_otp? && !user.confirmed?

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
