# frozen_string_literal: true

module RecordingStudioUsers
  module Services
    class AvatarMutation
      OPERATIONS = %i[upload replace remove].freeze

      def self.call(...)
        new(...).call
      end

      def initialize(operation:, user:, actor:, signed_blob_id: nil, impersonator: nil)
        @operation = operation.to_sym
        @user = user
        @actor = actor
        @signed_blob_id = signed_blob_id
        @impersonator = impersonator
      end

      def call
        return Result.failure("Unsupported avatar operation") unless OPERATIONS.include?(operation)
        return Result.failure("A persisted actor is required") unless actor&.persisted?
        return Result.failure("Not authorized to edit this Profile") unless authorized?
        if %i[upload replace].include?(operation) && signed_blob_id.blank?
          return Result.failure("signed_blob_id is required")
        end

        value = RecordingStudio::Recording.transaction do
          profile_recording = RecordingStudioUsers.profile_recording_for(user)
          profile_recording.lock!
          current = current_avatar!(profile_recording)
          validate_state!(current)
          dependency_result = within_context(profile_recording) { delegate(profile_recording, current) }
          raise Error, dependency_result.error if dependency_result.failure?

          verify_topology!(profile_recording, previous: current, result: dependency_result.value)
          dependency_result.value
        end
        Result.success(value)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, RecordingStudioUsers::Error,
             RecordingStudioAttachable::Error, ArgumentError => e
        errors = e.respond_to?(:record) ? e.record.errors.full_messages : []
        Result.failure(e, errors:)
      end

      private

      attr_reader :operation, :user, :actor, :signed_blob_id, :impersonator

      def authorized?
        profile = RecordingStudioUsers.profile_recording_for(user)
        RecordingStudioUsers.profile_editable?(user, actor:) &&
          RecordingStudioAccessible.authorized?(actor:, recording: profile, role: :edit)
      rescue ActiveRecord::RecordNotFound
        false
      end

      def current_avatar!(profile_recording)
        recordings = RecordingStudioUsers.active_avatar_recordings(profile_recording).lock.to_a
        raise TopologyError, "Profile has more than one active avatar" if recordings.many?

        recordings.first
      end

      def validate_state!(current)
        raise TopologyError, "Avatar already exists; use replace_avatar" if operation == :upload && current
        raise TopologyError, "Avatar does not exist" if %i[replace remove].include?(operation) && current.nil?
      end

      def within_context(profile_recording)
        context = {operation:, user:, profile_recording:, actor:, impersonator:}.freeze
        ExecutionContext.with(:avatar_mutation, context) { yield }
      end

      def delegate(profile_recording, current)
        service, arguments = dependency_service_and_arguments(profile_recording, current)
        service.call(**arguments, actor:, impersonator:)
      end

      def dependency_service_and_arguments(profile_recording, current)
        case operation
        when :upload
          [
            RecordingStudioAttachable::Services::RecordAttachmentUpload,
            {parent_recording: profile_recording, signed_blob_id:}
          ]
        when :replace
          [
            RecordingStudioAttachable::Services::ReplaceAttachmentFile,
            {attachment_recording: current, signed_blob_id:}
          ]
        when :remove
          [RecordingStudioAttachable::Services::RemoveAttachment, {attachment_recording: current}]
        end
      end

      def verify_topology!(profile_recording, previous:, result:)
        current = RecordingStudioUsers.active_avatar_recordings(profile_recording).to_a
        expected_count = operation == :remove ? 0 : 1
        raise TopologyError, "Avatar mutation produced invalid topology" unless current.size == expected_count
        return unless operation == :replace
        return if current.first.id == previous.id && result.id == previous.id

        raise TopologyError, "Avatar replacement changed the stable recording"
      end
    end
  end
end
