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
        popup = RecordingStudioUser::ReturnTo.popup?(session)
        rotate_session!
        sign_in(:user, user, **sign_in_options)
        session[RecordingStudioUser::ReturnTo::SESSION_KEY] = return_to if return_to
        session[RecordingStudioUser::ReturnTo::POPUP_KEY] = true if popup
      end

      def safe_return_location
        raw = stored_location_for(:user) || session[RecordingStudioUser::ReturnTo::SESSION_KEY]
        RecordingStudioUser::ReturnTo.accept(raw)
      end
    end
  end
end
