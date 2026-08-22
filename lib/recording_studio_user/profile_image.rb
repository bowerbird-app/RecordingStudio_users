# frozen_string_literal: true

module RecordingStudioUser
  # Public helpers for the single Attachable image under a Profile recording.
  module ProfileImage
    module_function

    def recording_for(user)
      recording = Directory.profile_recording_for(user)
      return if recording.blank?

      recording.images(per_page: 1).first
    end

    def attach!(user, io:, filename:, content_type:, actor: nil)
      recording = Directory.profile_recording_for(user)
      raise ArgumentError, "Profile recording is missing" if recording.blank?

      existing = recording_for(user)
      return existing if existing.present?

      import!(recording, io:, filename:, content_type:, actor: actor || user)
    end

    def import!(recording, io:, filename:, content_type:, actor:)
      result = RecordingStudioAttachable::Services::ImportAttachment.call(
        parent_recording: recording,
        io: io,
        filename: filename,
        content_type: content_type,
        actor: actor,
        name: File.basename(filename.to_s, File.extname(filename.to_s))
      )
      raise result.error if result.failure?

      result.value
    end
  end
end
