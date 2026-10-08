# frozen_string_literal: true

module RecordingStudioUser
  # Emits the unified registration-completed instrumentation event after commit.
  module RegistrationCompleted
    EVENT = "registration.completed.recording_studio_user"
    METHODS = %i[password oauth otp].freeze

    module_function

    def emit!(user_id:, method:)
      method = method.to_sym
      raise ArgumentError, "unsupported registration method: #{method.inspect}" unless METHODS.include?(method)

      ActiveRecord.after_all_transactions_commit do
        ActiveSupport::Notifications.instrument(EVENT, user_id: user_id, method: method)
      end
    end
  end
end
