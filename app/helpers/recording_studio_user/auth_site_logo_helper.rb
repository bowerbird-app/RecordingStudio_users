# frozen_string_literal: true

module RecordingStudioUser
  # Optional Site Settings mark on auth screens. Hosts that load
  # recording_studio_site_settings get the configured mark above the title when a
  # site root can be resolved. Without that gem this helper is a no-op.
  #
  # Attachable preview routes require a signed-in actor, so auth pages use an
  # Active Storage blob path from the host app routes instead.
  module AuthSiteLogoHelper
    def auth_site_logo(size: :xl, variant: :square_med)
      return unless defined?(RecordingStudioSiteSettings)

      root = auth_site_root_recording
      return if root.blank?

      if RecordingStudioUser.config.auth_logo_wide?
        render_auth_wide_logo(root)
      else
        render_auth_square_logo(root, size: size, variant: variant)
      end
    end

    def auth_site_root_recording
      resolver = RecordingStudioUser.config.auth_site_root_resolver
      return resolver.call(self) if resolver.respond_to?(:call)

      default_auth_site_root_recording
    end

    private

    def render_auth_square_logo(root, size:, variant:)
      src = auth_site_logo_public_src(
        RecordingStudioSiteSettings.square_logo_for(root, variant: variant)
      )
      return if src.blank?

      render FlatPack::Avatar::Component.new(
        src: src,
        size: size,
        shape: :square,
        alt: auth_site_logo_alt(root)
      )
    end

    def render_auth_wide_logo(root)
      src = auth_site_logo_public_src(
        RecordingStudioSiteSettings.wide_logo_for(root, variant: :small)
      )
      return if src.blank?

      render partial: "recording_studio_user/auth/wide_logo", locals: {
        src: src,
        alt: auth_site_logo_alt(root)
      }
    end

    def auth_site_logo_alt(root)
      RecordingStudioSiteSettings.name_for(root).presence || "Logo"
    end

    def auth_site_logo_public_src(logo)
      return if logo.blank?

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
