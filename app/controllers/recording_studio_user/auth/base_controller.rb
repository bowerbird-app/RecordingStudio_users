# frozen_string_literal: true

require_dependency RecordingStudioUser::Engine.root.join(
  "app/controllers/concerns/recording_studio_user/auth/pending_email.rb"
).to_s
require_dependency RecordingStudioUser::Engine.root.join(
  "app/controllers/concerns/recording_studio_user/auth/session_rotation.rb"
).to_s
require_dependency RecordingStudioUser::Engine.root.join(
  "app/controllers/concerns/recording_studio_user/auth/return_path.rb"
).to_s

module RecordingStudioUser
  module Auth
    class BaseController < ApplicationController
      include Devise::Controllers::Helpers
      include RecordingStudioUser::AuthRoutesHelper
      include RecordingStudioUser::Auth::PendingEmail
      include RecordingStudioUser::Auth::SessionRotation
      include RecordingStudioUser::Auth::ReturnPath
      include RecordingStudioUser::PasswordConfirmation::BindsSession

      private

      def resource_class
        RecordingStudioUser.config.user_class
      end

      def verify_failure_message(reason)
        I18n.t(
          "recording_studio_user.auth.verify.#{reason}",
          default: I18n.t("recording_studio_user.auth.that_code_did_not_work")
        )
      end

      def require_otp_enabled!
        return if RecordingStudioUser.config.otp_enabled?

        raise ActionController::RoutingError, "OTP authentication is not enabled"
      end

      def require_otp_registration_enabled!
        return if RecordingStudioUser.config.otp_enabled? &&
                  RecordingStudioUser.config.otp_registration_enabled?

        raise ActionController::RoutingError, "OTP registration is not enabled"
      end

      def require_otp_login_enabled!
        return if RecordingStudioUser.config.otp_enabled? &&
                  RecordingStudioUser.config.otp_login_enabled?

        raise ActionController::RoutingError, "OTP login is not enabled"
      end

      def generic_login_notice
        I18n.t("recording_studio_user.auth.eligible_code_sent")
      end

      def start_with_email_alert
        I18n.t("recording_studio_user.auth.start_with_email")
      end

      def host_new_user_session_path
        main_app.new_user_session_path
      end

      def host_new_user_registration_path
        main_app.new_user_registration_path
      end

      def user_for_otp_resend
        if session[:otp_user_id]
          resource_class.find_by(id: session[:otp_user_id])
        elsif session[:otp_challenge_id]
          RecordingStudioUser::OtpChallenge.find_by(id: session[:otp_challenge_id])&.user
        end
      end

      def confirm_password_signup!(user)
        result = RecordingStudioUser::Services::ConfirmPasswordSignup.call(user: user, session: session)
        confirmed = result.value.fetch(:user)
        unless result.value.fetch(:already_confirmed)
          RegistrationCompleted.emit!(
            user_id: confirmed.id,
            method: :password,
            source: SignupSource.take!(session)
          )
        end
        confirmed
      end

      def finish_password_confirmation!(user, sign_up: false)
        confirmed = confirm_password_signup!(user)
        sign_up ? finish_sign_up!(confirmed) : finish_sign_in!(confirmed)
      end
    end
  end
end
