# frozen_string_literal: true

module RecordingStudioUsers
  module AvatarAuthorization
    ACTIONS = {upload: :upload, replace: :revise, remove: :remove}.freeze

    module_function

    def call(action:, actor:, recording:, **)
      owner_recording = recording.recordable_type == "RecordingStudioAttachable::Attachment" ?
        recording.parent_recording : recording
      user = user_for_profile_recording(owner_recording)
      return false unless user

      return RecordingStudioUsers.stored_avatar_visible?(user, actor:) if %i[view download].include?(action.to_sym)

      context = ExecutionContext.fetch(:avatar_mutation)
      context.present? &&
        ACTIONS.fetch(context[:operation]) == action.to_sym &&
        context[:user] == user &&
        context[:profile_recording] == owner_recording &&
        context[:actor] == actor &&
        RecordingStudioUsers.profile_editable?(user, actor:)
    rescue KeyError, StandardError
      false
    end

    def user_for_profile_recording(profile_recording)
      return unless profile_recording&.recordable_type == "RecordingStudioUsers::Profile"

      root_recording = RecordingStudio::Recording.unscoped.find_by(id: profile_recording.root_recording_id)
      root = root_recording&.recordable
      root.user if root.is_a?(RecordingStudioUsers::UserRoot)
    end
  end
end
