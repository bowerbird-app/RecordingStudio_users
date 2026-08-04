# frozen_string_literal: true

module RecordingStudioUsers
  module Services
    class ReviseProfile
      def self.call(...)
        new(...).call
      end

      def initialize(user:, actor:, attributes:, impersonator: nil)
        @user = user
        @actor = actor
        @attributes = attributes
        @impersonator = impersonator
      end

      def call
        return Result.failure("A persisted actor is required") unless actor&.persisted?
        return Result.failure("Not authorized to edit this Profile") unless authorized?

        profile_recording = RecordingStudioUsers.profile_recording_for(user)
        root_recording = RecordingStudioUsers.user_root_recording_for(user)
        revised = root_recording.revise(profile_recording, actor:, impersonator:) do |profile|
          profile.assign_attributes(normalized_attributes)
        end
        Result.success(revised.recordable)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, RecordingStudioUsers::Error,
             ArgumentError => e
        errors = e.respond_to?(:record) ? e.record.errors.full_messages : []
        Result.failure(e, errors:)
      end

      private

      attr_reader :user, :actor, :attributes, :impersonator

      def authorized?
        profile = RecordingStudioUsers.profile_recording_for(user)
        RecordingStudioUsers.profile_editable?(user, actor:) &&
          RecordingStudioAccessible.authorized?(actor:, recording: profile, role: :edit)
      rescue ActiveRecord::RecordNotFound
        false
      end

      def normalized_attributes
        source = attributes.respond_to?(:to_h) ? attributes.to_h.stringify_keys : {}
        allowed = RecordingStudioUsers.configuration.profile_fields.map(&:to_s)
        rejected = source.keys - allowed
        raise ArgumentError, "Unsupported Profile attributes: #{rejected.join(', ')}" if rejected.any?

        source.slice(*allowed)
      end
    end
  end
end
