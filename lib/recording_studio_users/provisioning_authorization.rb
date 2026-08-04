# frozen_string_literal: true

module RecordingStudioUsers
  module ProvisioningAuthorization
    class << self
      def install!
        return unless defined?(RecordingStudioAccessible)

        configuration = RecordingStudioAccessible.configuration
        current = configuration.access_management_authorizer
        return if current.respond_to?(:recording_studio_users_authorizer?)

        wrapper = build_wrapper(current)
        configuration.access_management_authorizer = wrapper
      end

      def with_context(user:, user_root:, root_recording:, actor:, &)
        context = { user:, user_root:, root_recording:, actor:, role: :admin }.freeze
        ExecutionContext.with(:provisioning, context, &)
      end

      private

      def build_wrapper(original)
        wrapper = lambda do |recording:, actor: nil, controller: nil, **|
          provisioning_allowed?(recording:, actor:) ||
            call_original(original, recording:, actor:, controller:)
        end
        wrapper.define_singleton_method(:recording_studio_users_authorizer?) { true }
        wrapper.define_singleton_method(:recording_studio_users_original) { original }
        wrapper
      end

      def provisioning_allowed?(recording:, actor:)
        context = ExecutionContext.fetch(:provisioning)
        return false unless context
        return false unless recording == context[:root_recording]
        return false unless actor == context[:actor] && actor&.persisted?
        return false unless recording.recordable == context[:user_root]
        return false unless context[:user_root].user == context[:user]
        return false unless context[:role] == :admin

        RecordingStudioAccessible.access_recordings_for(recording).none?
      rescue StandardError
        false
      end

      def call_original(original, **)
        return false unless original.respond_to?(:call)

        !!original.call(**)
      rescue StandardError
        false
      end
    end
  end
end
