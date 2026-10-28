# frozen_string_literal: true

require "recording_studio_user/profile_image/blobs"

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
      recording = require_profile_recording!(user)
      existing = recording_for(user)
      return existing if existing.present?

      import!(recording, io:, filename:, content_type:, actor: actor || user)
    end

    def assign_signed!(user, signed_blob_id:, actor: nil)
      recording = require_profile_recording!(user)
      actor ||= user
      existing = recording_for(user)
      result = if existing.present?
                 replace_signed!(existing, signed_blob_id, actor)
               else
                 upload_signed!(recording, signed_blob_id, actor)
               end
      finish!(result)
    end

    def remove!(user, actor: nil)
      existing = recording_for(user)
      return if existing.blank?

      result = RecordingStudioAttachable::Services::RemoveAttachment.call(
        attachment_recording: existing,
        actor: actor || user
      )
      finish!(result)
    end

    def replace!(user, io:, filename:, content_type:, actor: nil)
      recording = require_profile_recording!(user)
      existing = recording_for(user)
      actor ||= user
      return import!(recording, io:, filename:, content_type:, actor: actor) if existing.blank?

      replace_existing!(existing, io:, filename:, content_type:, actor: actor)
    end

    def require_profile_recording!(user)
      recording = Directory.profile_recording_for(user)
      raise ArgumentError, "Profile recording is missing" if recording.blank?

      recording
    end

    def replace_existing!(existing, io:, filename:, content_type:, actor:)
      owner = existing.parent_recording
      blob = Blobs.issued!(owner, io:, filename:, content_type:, actor:)
      result = RecordingStudioAttachable::Services::ReplaceAttachmentFile.call(
        attachment_recording: existing,
        signed_blob_id: RecordingStudioAttachable::DirectUpload.sign(blob),
        actor: actor
      )
      raise result.error if result.failure?

      result.value
    end

    def replace_signed!(existing, signed_blob_id, actor)
      RecordingStudioAttachable::Services::ReplaceAttachmentFile.call(
        attachment_recording: existing,
        signed_blob_id: signed_blob_id,
        actor: actor
      )
    end

    def upload_signed!(recording, signed_blob_id, actor)
      RecordingStudioAttachable::Services::RecordAttachmentUpload.call(
        parent_recording: recording,
        signed_blob_id: signed_blob_id,
        actor: actor,
        name: "Profile"
      )
    end

    def finish!(result)
      return result.value if result.success?

      error = result.error
      raise error if error.is_a?(Exception)

      raise ArgumentError, error.to_s
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
