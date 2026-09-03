# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    class PasswordsController < Devise::PasswordsController
      include Rails.application.routes.mounted_helpers

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
    end
  end
end
