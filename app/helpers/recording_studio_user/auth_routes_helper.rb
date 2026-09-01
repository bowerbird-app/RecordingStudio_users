# frozen_string_literal: true

module RecordingStudioUser
  module AuthRoutesHelper
    def otp_registration_password_path
      if respond_to?(:user_registration_path)
        "#{new_user_registration_path}/password"
      else
        recording_studio_users.sign_up_password_path
      end
    end

    def otp_registration_otp_path
      if respond_to?(:new_user_registration_path)
        "#{new_user_registration_path}/otp"
      else
        recording_studio_users.sign_up_otp_path
      end
    end

    def otp_registration_verify_path
      respond_to?(:verify_user_registration_path) ? verify_user_registration_path : recording_studio_users.sign_up_verify_path
    end

    def otp_registration_resend_path
      respond_to?(:resend_user_registration_path) ? resend_user_registration_path : recording_studio_users.sign_up_resend_path
    end

    def otp_session_password_path
      respond_to?(:user_session_path) ? "#{new_user_session_path}/password" : recording_studio_users.sign_in_password_path
    end

    def otp_session_otp_path
      respond_to?(:new_user_session_path) ? "#{new_user_session_path}/otp" : recording_studio_users.sign_in_otp_path
    end

    def otp_session_verify_path
      respond_to?(:verify_user_session_path) ? verify_user_session_path : recording_studio_users.sign_in_verify_path
    end

    def otp_session_resend_path
      respond_to?(:resend_user_session_path) ? resend_user_session_path : recording_studio_users.sign_in_resend_path
    end
  end
end
