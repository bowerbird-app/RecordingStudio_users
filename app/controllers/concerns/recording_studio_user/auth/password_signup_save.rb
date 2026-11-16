# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    module PasswordSignupSave
      extend ActiveSupport::Concern

      private

      def persist_password_signup?
        RecordingStudioUser::OtpSetup.ensure_confirmation_codes!
        saved = save_password_account!
        RecordingStudioUser::PasswordConfirmation.mark!(session, resource) if saved
        saved
      end

      def save_password_account!
        saved = RecordingStudioUser::OtpDeliveryDeferral.defer { write_password_account! }
        RecordingStudioUser::OtpDeliveryDeferral.flush! if saved
        saved
      rescue StandardError
        RecordingStudioUser::OtpDeliveryDeferral.discard!
        raise
      end

      def write_password_account!
        ActiveRecord::Base.transaction do
          next false unless resource.save

          provision_password_account!
          @confirmation_code = request_confirmation_code!(resource.email)
          true
        end
      end
    end
  end
end
