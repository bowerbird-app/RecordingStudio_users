# frozen_string_literal: true

require "recording_studio_site_settings/store/images"

module RecordingStudioSiteSettings
  RECORDABLE_TYPE = "RecordingStudioSiteSettings::SiteSetting"

  module Store
    module_function

    SQUARE_LOGO_SLOT = Images::SQUARE_LOGO_SLOT
    WIDE_LOGO_SLOT = Images::WIDE_LOGO_SLOT
    FAVICON_SLOT = Images::FAVICON_SLOT
    LOGO_SLOT = Images::LOGO_SLOT
    IMAGE_SLOTS = Images::IMAGE_SLOTS

    def square_logo_for(...) = Images.square_logo_for(...)
    def wide_logo_for(...) = Images.wide_logo_for(...)
    def logo_for(...) = Images.logo_for(...)
    def favicon_for(...) = Images.favicon_for(...)
    def square_logo_recording_for(...) = Images.square_logo_recording_for(...)
    def wide_logo_recording_for(...) = Images.wide_logo_recording_for(...)
    def logo_recording_for(...) = Images.logo_recording_for(...)
    def favicon_recording_for(...) = Images.favicon_recording_for(...)

    def name_for(root_recording)
      settings_for(root_recording)&.name
    end

    def recording_for(root_recording)
      return if root_recording.blank?

      RecordingStudio::Recording.find_by(
        root_recording_id: root_recording.id,
        parent_recording_id: root_recording.id,
        recordable_type: RECORDABLE_TYPE,
        trashed_at: nil
      )
    end

    def settings_for(root_recording)
      recording_for(root_recording)&.recordable
    end

    def update!(root_recording, name:, actor:, **file)
      authorize_write!(root_recording, actor)
      recording = ensure_recording!(root_recording, name: name, actor: actor)
      revise_name!(recording, name: name, actor: actor)
      IMAGE_SLOTS.each do |slot, keys|
        args = file_args_for(file, slot, keys)
        next if args.blank?

        Images.attach_named_image!(recording, actor: actor, slot: slot, **args)
      end
      recording.reload
    end

    def file_args_for(file, slot, keys)
      io = first_present(file, keys.fetch(:io))
      return if io.blank?

      {
        io: io,
        filename: first_present(file, keys.fetch(:filename)) || "#{slot}.png",
        content_type: first_present(file, keys.fetch(:content_type)) || "image/png"
      }
    end

    def first_present(file, keys)
      keys.lazy.map { |key| file[key] }.find(&:present?)
    end

    def site_root?(recording)
      return false if recording.blank?

      type_name = RecordingStudio.recordable_type_name(recording.recordable)
      Array(RecordingStudioSiteSettings.configuration.site_root_types).include?(type_name)
    end

    def site_root_for(context)
      RecordingStudioSiteSettings.configuration.site_root_resolver.call(context)
    end

    def authorize_write!(root_recording, actor)
      allowed = RecordingStudioAccessible.authorized?(actor:, recording: root_recording, role: :edit)
      raise Unauthorized, "You cannot change this site's name, logos, or tab icon." unless allowed
    end

    def ensure_recording!(root_recording, name:, actor:)
      existing = recording_for(root_recording)
      return existing if existing.present?

      with_actor(actor) { root_recording.record(SiteSetting, actor: actor) { |settings| settings.name = name } }
    end

    def revise_name!(recording, name:, actor:)
      return recording if recording.recordable&.name == name

      with_actor(actor) do
        recording.root_recording.revise(recording, actor: actor) { |settings| settings.name = name }
      end
    end

    def with_actor(actor)
      previous_actor = Current.actor if defined?(Current)
      Current.actor = actor if defined?(Current)
      yield
    ensure
      Current.actor = previous_actor if defined?(Current)
    end
  end
end
