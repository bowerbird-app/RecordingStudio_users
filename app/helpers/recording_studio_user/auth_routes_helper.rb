# frozen_string_literal: true

module RecordingStudioUser
  module AuthRoutesHelper
    def otp_registration_password_path
      if host_routes?(:new_user_registration_path)
        "#{host_new_user_registration_path}/password"
      else
        recording_studio_users.sign_up_password_path
      end
    end

    def otp_registration_otp_path
      if host_routes?(:new_user_registration_path)
        "#{host_new_user_registration_path}/otp"
      else
        recording_studio_users.sign_up_otp_path
      end
    end

    def otp_registration_verify_path
      if host_routes?(:verify_user_registration_path)
        host_verify_user_registration_path
      else
        recording_studio_users.sign_up_verify_path
      end
    end

    def otp_registration_resend_path
      if host_routes?(:resend_user_registration_path)
        host_resend_user_registration_path
      else
        recording_studio_users.sign_up_resend_path
      end
    end

    def otp_session_password_path
      if host_routes?(:new_user_session_path)
        "#{host_new_user_session_path}/password"
      else
        recording_studio_users.sign_in_password_path
      end
    end

    def otp_session_otp_path
      if host_routes?(:new_user_session_path)
        "#{host_new_user_session_path}/otp"
      else
        recording_studio_users.sign_in_otp_path
      end
    end

    def otp_session_verify_path
      if host_routes?(:verify_user_session_path)
        host_verify_user_session_path
      else
        recording_studio_users.sign_in_verify_path
      end
    end

    def otp_session_resend_path
      if host_routes?(:resend_user_session_path)
        host_resend_user_session_path
      else
        recording_studio_users.sign_in_resend_path
      end
    end

    private

    def host_routes?(route_name)
      respond_to?(:main_app) && main_app.respond_to?(route_name)
    end

    def host_new_user_registration_path
      main_app.new_user_registration_path
    end

    def host_new_user_session_path
      main_app.new_user_session_path
    end

    def host_verify_user_registration_path
      main_app.verify_user_registration_path
    end

    def host_resend_user_registration_path
      main_app.resend_user_registration_path
    end

    def host_verify_user_session_path
      main_app.verify_user_session_path
    end

    def host_resend_user_session_path
      main_app.resend_user_session_path
    end
  end
end
