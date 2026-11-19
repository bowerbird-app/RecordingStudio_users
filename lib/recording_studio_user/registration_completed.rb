# frozen_string_literal: true

module RecordingStudioUser
  # Emits registration.completed.recording_studio_user after commit.
  # Host after_registration hooks run in the same after-commit callback.
  # The payload stays { user_id:, method: } unless a signup source was passed.
  module RegistrationCompleted
    EVENT = "registration.completed.recording_studio_user"
    METHODS = %i[password oauth otp].freeze

    module_function

    def emit!(user_id:, method:, source: nil)
      method = method.to_sym
      raise ArgumentError, "unsupported registration method: #{method.inspect}" unless METHODS.include?(method)

      source = SignupSource.normalize!(source) unless source.nil?
      payload = { user_id: user_id, method: method }
      payload[:source] = source unless source.nil?

      ActiveRecord.after_all_transactions_commit do
        ActiveSupport::Notifications.instrument(EVENT, payload)
        AfterRegistration.run!(user_id: user_id, method: method, source: source)
      end
    end
  end
end
