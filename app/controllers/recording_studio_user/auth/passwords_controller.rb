# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    class PasswordsController < Devise::PasswordsController
      def create
        user = resource_class.find_by(email: resource_params[:email].to_s.strip.downcase)
        if user&.otp_authentication_method?
          flash[:notice] = "This account signs in with email codes. Use Email OTP on the sign-in page."
          redirect_to new_user_session_path and return
        end

        super
      end

      private

      def resource_class
        RecordingStudioUser.config.user_class
      end
    end
  end
end
