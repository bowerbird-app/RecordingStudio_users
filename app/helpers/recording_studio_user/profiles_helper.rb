# frozen_string_literal: true

module RecordingStudioUser
  module ProfilesHelper
    PROFILE_IMAGE_UPLOAD_CONTROLLER = "recording-studio-attachable--attachment-revision-upload"
    PROFILE_IMAGE_UPLOAD_OPTIONS = %i[
      allowed_content_types
      max_file_size
      image_processing_enabled
      image_processing_max_width
      image_processing_max_height
      image_processing_quality
    ].freeze

    def profile_display_name(user)
      RecordingStudioUser.display_name_for(user)
    end

    def profile_locale_allowlisted?
      ProfileLocales.allowlisted?
    end

    def profile_language_options(profile)
      ProfileLocales.select_options(profile&.locale)
    end

    def profile_language_name(profile)
      ProfileLocales.label_for(profile&.locale)
    end

    def profile_image_recording(profile_recording)
      return if profile_recording.blank?

      profile_recording.images(per_page: 1).first
    end

    # The file-button partial calls this from a Users view. Attachable only
    # mixes the helper into its own controllers.
    def recording_direct_uploads_path(recording)
      recording_studio_attachable.recording_direct_uploads_path(recording)
    end

    def profile_image_accept
      types = profile_image_upload_options[:allowed_content_types]
      list = Array(types).join(",")
      list.presence || "image/*"
    end

    def profile_image_upload_data(recording)
      prefix = PROFILE_IMAGE_UPLOAD_CONTROLLER.tr("-", "_")
      values = profile_image_upload_values(recording)
      base = { controller: PROFILE_IMAGE_UPLOAD_CONTROLLER, action: profile_image_upload_action }
      base.merge(values.compact.transform_keys { |key| :"#{prefix}_#{key}_value" })
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

    private

    def attachable_routes
      recording_studio_attachable
    end

    def profile_image_upload_action
      "submit->#{PROFILE_IMAGE_UPLOAD_CONTROLLER}#handleSubmit"
    end

    def profile_image_upload_values(recording)
      {
        direct_upload_url: recording_direct_uploads_path(recording),
        signed_blob_field_name: "profile_image[signed_blob_id]",
        auto_submit: false,
        **profile_image_upload_options.except(:allowed_content_types)
      }
    end

    def profile_image_upload_options
      configured = RecordingStudio.capability_options(:attachable, for_type: "RecordingStudioUser::Profile").to_h
      PROFILE_IMAGE_UPLOAD_OPTIONS.index_with do |option|
        configured.fetch(option) { RecordingStudioAttachable.configuration.public_send(option) }
      end
    end
  end
end
