# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    class PasswordsController < Devise::PasswordsController
      include Rails.application.routes.mounted_helpers
      include RecordingStudioUser::AuthRoutesHelper

      layout "recording_studio_user/auth"

      def create
        user = resource_class.find_by(email: resource_params[:email].to_s.strip.downcase)
        if user&.registered_with_otp?
          flash[:notice] = "This account signs in with email codes. Use Email OTP on the sign-in page."
          redirect_to host_new_user_session_path and return
        end

        super
      end

      private

      def resource_class
        RecordingStudioUser.config.user_class
      end

      def host_new_user_session_path
        main_app.new_user_session_path
      end

      def after_resetting_password_path_for(_resource)
        main_app.root_path
      end

      def after_sending_reset_password_instructions_path_for(_resource_name)
        auth_sign_in_path
      end
    end
  end
end
