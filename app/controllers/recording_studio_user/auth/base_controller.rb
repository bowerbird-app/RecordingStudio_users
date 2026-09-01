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

      def rotate_session!
        reset_session
      end

      def store_return_location
        session[:user_return_to] = stored_location_for(:user)
      end

      def sign_in_user!(user)
        rotate_session!
        sign_in(:user, user)
      end

      def generic_login_notice
        "If an eligible account exists, we sent a code."
      end
    end
  end
end
