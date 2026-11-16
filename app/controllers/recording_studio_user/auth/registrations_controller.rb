# frozen_string_literal: true

require_dependency RecordingStudioUser::Engine.root.join(
  "app/controllers/concerns/recording_studio_user/auth/password_signup_save.rb"
).to_s
require_dependency RecordingStudioUser::Engine.root.join(
  "app/controllers/concerns/recording_studio_user/auth/registration_otp.rb"
).to_s
require_dependency RecordingStudioUser::Engine.root.join(
  "app/controllers/concerns/recording_studio_user/auth/signup_terms_acceptance.rb"
).to_s

module RecordingStudioUser
  module Auth
    class RegistrationsController < BaseController
      include RegistrationOtp
      include PasswordSignupSave
      include SignupTermsAcceptance

      before_action :require_password_registration!, only: %i[password create_password]
      before_action :require_otp_registration_enabled!, only: %i[otp create_otp]
      before_action :require_signup_code_screen!, only: %i[verify submit_verify resend]

      def new
        @resource = resource_class.new
      end

      def continue
        email = submitted_email_from_params
        return render_continue_failure(I18n.t("recording_studio_user.auth.enter_email")) if email.blank?

        store_pending_auth_email!(email)
        continue_with_primary_registration!(email)
      end

      def password
        email = pending_auth_email
        return redirect_to host_new_user_registration_path, alert: start_with_email_alert if email.blank?

        build_password_resource(email: email)
      end

      def create_password
        build_password_resource(sign_up_params)
        return render_password_taken if existing_account?(submitted_email)
        return render :password, status: :unprocessable_entity unless persist_password_signup?

        redirect_to otp_registration_verify_path, **confirmation_code_flash(@confirmation_code)
      end

      def otp; end

      def create_otp
        start_otp_registration!(submitted_email)
      end

      def verify
        # Same page whether or not a code was sent.
      end

      def submit_verify
        result = verify_signup_code
        return render_verify_failure(result) unless result.success?

        if result.challenge.confirmation?
          finish_password_confirmation!(result.user, sign_up: true)
        else
          user = RecordingStudioUser.complete_registration!(user: result.user, challenge: result.challenge)
          finish_sign_up!(user)
        end
      end

      def resend
        result = issue_registration_resend!
        if result&.throttled?
          redirect_to otp_registration_verify_path, alert: I18n.t("recording_studio_user.auth.wait_for_code")
          return
        end

        redirect_to otp_registration_verify_path, notice: I18n.t("recording_studio_user.auth.fresh_code")
      end

      private

      attr_reader :resource

      def build_password_resource(attrs = {})
        @resource = resource_class.new(attrs)
        @resource.registered_with = "password" if @resource.respond_to?(:registered_with=)
        @resource.skip_confirmation_notification! if @resource.respond_to?(:skip_confirmation_notification!)
      end

      def sign_up_params
        params.require(:user).permit(:email, :password, :password_confirmation)
      end

      def submitted_email
        @submitted_email ||= sign_up_params[:email].to_s.strip.downcase
      end

      def existing_account?(email)
        resource_class.find_for_database_authentication(email: email).present?
      end

      def render_continue_failure(message)
        @resource = resource_class.new(email: submitted_email_from_params)
        flash.now[:alert] = message
        render :new, status: :unprocessable_entity
      end

      def render_password_taken
        flash.now[:alert] = email_taken_message
        render :password, status: :unprocessable_entity
      end

      def provision_password_account!
        RecordingStudioUser.record_profile!(resource, actor: resource, **Profile.default_attributes_for(resource))
        accept_pending_terms_on_signup!(resource)
      end

      def render_verify_failure(result)
        flash.now[:alert] = verify_failure_message(result.reason)
        render :verify, status: :unprocessable_entity
      end
    end
  end
end
