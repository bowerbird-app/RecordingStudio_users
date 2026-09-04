# frozen_string_literal: true

module RecordingStudioSiteSettings
  module Store
    module Images
      module_function

      SQUARE_LOGO_SLOT = "square_logo"
      WIDE_LOGO_SLOT = "wide_logo"
      FAVICON_SLOT = "favicon"
      LOGO_SLOT = SQUARE_LOGO_SLOT

      IMAGE_SLOTS = {
        SQUARE_LOGO_SLOT => {
          io: %i[square_logo_io logo_io],
          filename: %i[square_logo_filename filename],
          content_type: %i[square_logo_content_type content_type]
        },
        WIDE_LOGO_SLOT => {
          io: %i[wide_logo_io],
          filename: %i[wide_logo_filename],
          content_type: %i[wide_logo_content_type]
        },
        FAVICON_SLOT => {
          io: %i[favicon_io],
          filename: %i[favicon_filename],
          content_type: %i[favicon_content_type]
        }
      }.freeze

      def square_logo_for(root_recording, variant: :square_med)
        mark_for(square_logo_recording_for(root_recording), variant: variant)
      end

      def wide_logo_for(root_recording, variant: :small)
        mark_for(wide_logo_recording_for(root_recording), variant: variant)
      end

      def logo_for(root_recording, variant: :square_med)
        square_logo_for(root_recording, variant: variant)
      end

      def favicon_for(root_recording, variant: :square_small)
        mark_for(favicon_recording_for(root_recording), variant: variant)
      end

      def square_logo_recording_for(root_recording)
        named_image(Store.recording_for(root_recording), SQUARE_LOGO_SLOT)
      end

      def wide_logo_recording_for(root_recording)
        named_image(Store.recording_for(root_recording), WIDE_LOGO_SLOT)
      end

      def logo_recording_for(root_recording)
        square_logo_recording_for(root_recording)
      end

      def favicon_recording_for(root_recording)
        named_image(Store.recording_for(root_recording), FAVICON_SLOT)
      end

      def attach_named_image!(parent_recording, actor:, slot:, **file)
        existing = named_image(parent_recording, slot)
        return replace_image!(existing, actor:, **file) if existing.present?

        import_image!(parent_recording, actor:, slot:, **file)
      end

      def named_image(parent_recording, slot)
        images_for(parent_recording).find { |recording| image_slot_name(recording).casecmp?(slot) }
      end

      def images_for(parent_recording)
        return [] if parent_recording.blank? || !parent_recording.respond_to?(:images)

        Array(parent_recording.images(per_page: 24))
      end

      def image_slot_name(recording)
        recording.recordable&.name.to_s
      end

      def mark_for(attachment, variant:)
        Logo.new(attachment, preview_url_for(attachment, variant), filename_for(attachment))
      end

      def replace_image!(existing, actor:, **file)
        blob = ActiveStorage::Blob.create_and_upload!(
          io: file.fetch(:io),
          filename: file.fetch(:filename),
          content_type: file.fetch(:content_type)
        )
        existing.replace_attachment_file(signed_blob_id: blob.signed_id, actor: actor)
      end

      def import_image!(parent_recording, actor:, slot:, **file)
        result = RecordingStudioAttachable::Services::ImportAttachment.call(
          parent_recording: parent_recording,
          io: file.fetch(:io),
          filename: file.fetch(:filename),
          content_type: file.fetch(:content_type),
          actor: actor,
          name: slot
        )
        raise result.error if result.failure?

        result.value
      end

      def preview_url_for(attachment_recording, variant)
        return if attachment_recording.blank?

        RecordingStudioAttachable::Engine.routes.url_helpers.attachment_preview_file_path(
          attachment_recording,
          variant_name: variant
        )
      rescue StandardError
        nil
      end

      def filename_for(attachment_recording)
        attachment_recording&.recordable&.original_filename
      end
    end
  end
end
