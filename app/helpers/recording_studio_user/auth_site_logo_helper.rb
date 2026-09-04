# frozen_string_literal: true

module RecordingStudioUser
  # Optional Site Settings mark on auth screens. Hosts that load
  # recording_studio_site_settings get the square logo above the title when a
  # site root can be resolved. Without that gem this helper is a no-op.
  #
  # Attachable preview routes require a signed-in actor, so auth pages use an
  # Active Storage blob path from the host app routes instead.
  module AuthSiteLogoHelper
    def auth_site_logo(size: :xl, variant: :square_med)
      return unless defined?(RecordingStudioSiteSettings)

      root = auth_site_root_recording
      return unless root

      logo = RecordingStudioSiteSettings.square_logo_for(root, variant: variant)
      return if logo.blank?

      src = auth_site_logo_public_src(logo)
      return if src.blank?

      name = RecordingStudioSiteSettings.name_for(root)
      render FlatPack::Avatar::Component.new(
        src: src,
        size: size,
        shape: :square,
        alt: name.presence || "Logo"
      )
    end

    def auth_site_root_recording
      resolver = RecordingStudioUser.config.auth_site_root_resolver
      return resolver.call(self) if resolver.respond_to?(:call)

      default_auth_site_root_recording
    end

    private

    def auth_site_logo_public_src(logo)
      attachment = logo.recording&.recordable
      return unless attachment.respond_to?(:file) && attachment.file.attached?

      # Original blob path — Attachable preview routes need a signed-in actor,
      # and variant URLs need an image processor. Avatar sizes via `size:`.
      # Host app routes: engine views may not expose Active Storage helpers.
      Rails.application.routes.url_helpers.rails_blob_path(attachment.file, only_path: true)
    rescue StandardError
      nil
    end

    def default_auth_site_root_recording
      return unless defined?(AdminRoot)

      admin = AdminRoot.find_by(name: "Admin") || AdminRoot.order(:name).first
      return unless admin

      RecordingStudio.root_recording_for(admin)
    end
  end
end
