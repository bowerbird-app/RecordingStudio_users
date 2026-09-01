# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    class BaseController < ApplicationController
      include Devise::Controllers::Helpers
      include RecordingStudioUser::AuthRoutesHelper

      before_action :require_otp_enabled!

      layout RecordingStudioUser.config.layout

      private

      def require_otp_enabled!
        return if RecordingStudioUser.config.otp_enabled?

        raise ActionController::RoutingError, "OTP authentication is not enabled"
      end

      def require_otp_registration_enabled!
        return if RecordingStudioUser.config.otp_registration_enabled?

        raise ActionController::RoutingError, "OTP registration is not enabled"
      end

      def require_otp_login_enabled!
        return if RecordingStudioUser.config.otp_login_enabled?

        raise ActionController::RoutingError, "OTP login is not enabled"
      end

      def rotate_session!
        reset_session
      end

      def sign_in_user!(user)
        return_to = safe_return_location
        rotate_session!
        sign_in(:user, user)
        session[:user_return_to] = return_to if return_to
      end

      def safe_return_location
        location = stored_location_for(:user) || session[:user_return_to]
        return unless location.is_a?(String)
        return unless location.start_with?("/")
        return if location.start_with?("//")

        location
      end

      def after_sign_in_path_for(resource)
        stored_location_for(resource) || main_app.root_path
      end

      def after_sign_up_path_for(resource)
        stored_location_for(resource) || main_app.root_path
      end

      def generic_login_notice
        "If an eligible account exists, we sent a code."
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
    end
  end
end
