# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    module SessionRotation
      extend ActiveSupport::Concern

      private

      def rotate_session!
        reset_session
      end

      def sign_in_user!(user, **sign_in_options)
        return_to = safe_return_location
        rotate_session!
        sign_in(:user, user, **sign_in_options)
        session[:user_return_to] = return_to if return_to
      end

      def safe_return_location
        location = stored_location_for(:user) || session[:user_return_to]
        return unless location.is_a?(String)
        return unless location.start_with?("/")
        return if location.start_with?("//")

        location
      end
    end
  end
end
