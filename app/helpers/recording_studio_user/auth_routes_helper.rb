# frozen_string_literal: true

module RecordingStudioUser
  module AuthRoutesHelper
    def otp_registration_password_path
      host_suffix_or_engine(:new_user_registration_path, "/password", :sign_up_password_path)
    end

    def otp_registration_otp_path
      host_suffix_or_engine(:new_user_registration_path, "/otp", :sign_up_otp_path)
    end

    def otp_registration_verify_path
      host_or_engine(:verify_user_registration_path, :sign_up_verify_path)
    end

    def otp_registration_resend_path
      host_or_engine(:resend_user_registration_path, :sign_up_resend_path)
    end

    def otp_session_password_path
      host_suffix_or_engine(:new_user_session_path, "/password", :sign_in_password_path)
    end

    def otp_session_otp_path
      host_suffix_or_engine(:new_user_session_path, "/otp", :sign_in_otp_path)
    end

    def otp_session_verify_path
      host_or_engine(:verify_user_session_path, :sign_in_verify_path)
    end

    def otp_session_resend_path
      host_or_engine(:resend_user_session_path, :sign_in_resend_path)
    end

    def password_session_path
      host_or_engine(:user_session_path, :sign_in_password_path)
    end

    def password_registration_path
      host_or_engine(:user_registration_path, :sign_up_password_path)
    end

    def auth_sign_up_path
      host_or_engine(:new_user_registration_path, :sign_up_path)
    end

    def auth_sign_in_path
      host_or_engine(:new_user_session_path, :sign_in_path)
    end

    def continue_session_path
      auth_sign_in_path
    end

    def continue_registration_path
      auth_sign_up_path
    end

    private

    def host_routes?(route_name)
      respond_to?(:main_app) && main_app.respond_to?(route_name)
    end

    def host_or_engine(host_route, engine_route)
      if host_routes?(host_route)
        main_app.public_send(host_route)
      else
        recording_studio_users.public_send(engine_route)
      end
    end

    def host_suffix_or_engine(host_route, suffix, engine_route)
      if host_routes?(host_route)
        "#{main_app.public_send(host_route)}#{suffix}"
      else
        recording_studio_users.public_send(engine_route)
      end
    end

    def host_new_user_registration_path
      main_app.new_user_registration_path
    end

    def host_new_user_session_path
      main_app.new_user_session_path
    end
  end
end
