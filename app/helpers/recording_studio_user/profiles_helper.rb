# frozen_string_literal: true

module RecordingStudioUser
  module ProfilesHelper
    def profile_display_name(user)
      RecordingStudioUser.display_name_for(user)
    end

    def profile_image_recording(profile_recording)
      return if profile_recording.blank?

      profile_recording.images(per_page: 1).first
    end

    def profile_image_preview_path(attachment_recording, variant: :square_med)
      return if attachment_recording.blank?

      attachment = attachment_recording.recordable
      if attachment.respond_to?(:preview_target_named) && attachment.preview_target_named(variant).present?
        attachable_routes.attachment_preview_file_path(attachment_recording, variant_name: variant)
      else
        attachable_routes.attachment_file_path(attachment_recording)
      end
    end

    def profile_image_upload_path(profile_recording, return_to: profile_path)
      attachable_routes.recording_attachment_upload_path(
        profile_recording,
        redirect_mode: "return_to",
        return_to: return_to
      )
    end

    def profile_image_replace_path(attachment_recording, return_to: profile_path)
      attachable_routes.attachment_path(
        attachment_recording,
        redirect_mode: "return_to",
        return_to: return_to
      )
    end

    private

    def attachable_routes
      return recording_studio_attachable if respond_to?(:recording_studio_attachable)

      main_app.recording_studio_attachable
    end
  end
end
