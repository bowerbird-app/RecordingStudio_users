# frozen_string_literal: true

module RecordingStudioUsers
  module Services
    class LogUserEvent
      SENSITIVE_KEYS = /password|token|secret|session|signed_blob|blob_key|credential|api_key|provider|url/i

      def self.call(...)
        new(...).call
      end

      def initialize(user:, action:, actor:, impersonator: nil, metadata: {}, idempotency_key: nil)
        @user = user
        @action = action.to_s
        @actor = actor
        @impersonator = impersonator
        @metadata = metadata
        @idempotency_key = idempotency_key
      end

      def call
        return Result.failure("Event action is not registered") unless configuration.event_actions.include?(action)
        return Result.failure("A persisted actor is required") unless actor&.persisted?

        recording = RecordingStudioUsers.user_root_recording_for(user)
        event = recording.log_event!(
          action:,
          actor:,
          impersonator:,
          metadata: sanitized_metadata,
          idempotency_key:
        )
        Result.success(event)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, ArgumentError => e
        Result.failure(e)
      end

      private

      attr_reader :user, :action, :actor, :impersonator, :metadata, :idempotency_key

      def configuration = RecordingStudioUsers.configuration

      def sanitized_metadata
        source = metadata.respond_to?(:to_h) ? metadata.to_h : {}
        source.each_with_object({}) do |(key, value), result|
          next if key.to_s.match?(SENSITIVE_KEYS)
          next unless scalar?(value)

          result[key.to_s] = value.is_a?(String) ? value.truncate(500) : value
        end
      end

      def scalar?(value)
        value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false || value.nil?
      end
    end
  end
end
