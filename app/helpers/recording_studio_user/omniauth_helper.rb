# frozen_string_literal: true

module RecordingStudioUser
  module OmniauthHelper
    def recording_studio_user_omniauth_configured?
      RecordingStudioUser.config.omniauth_configured?
    end

    def recording_studio_user_omniauth_provider_names
      RecordingStudioUser.config.omniauth_provider_names
    end

    def recording_studio_user_provider_configured?(provider)
      RecordingStudioUser.config.omniauth_providers.key?(provider.to_sym)
    end

    def recording_studio_user_omniauth_authorize_path(provider)
      return unless recording_studio_user_provider_configured?(provider)

      helper_name = "user_#{provider}_omniauth_authorize_path"
      return unless main_app.respond_to?(helper_name)

      main_app.public_send(helper_name)
    end

    def recording_studio_user_provider_connected?(user, provider)
      return false if user.nil?

      user.respond_to?(:identity_for) && user.identity_for(provider).present?
    end

    def recording_studio_user_provider_label(provider)
      RecordingStudioUser::Omniauth.provider_label(provider)
    end

    # Flatpack List::Item can lead with an inline SVG via `icon:` or text/HTML via `leading:`.
    # It has no first-class image URL prop — configured logo URLs use `leading:` with an <img>.
    # Prefer `leading:` for SVGs so the mark sits in a fixed square and middle-aligns with actions.
    def recording_studio_user_provider_list_item_leading(provider)
      logo = recording_studio_user_provider_logo(provider)
      return {} if logo.blank?
      return { leading: provider_logo_svg_mark(logo) } if logo.to_s.start_with?("<svg")

      { leading: image_tag(logo, alt: "", class: "h-8 w-8 shrink-0", aria: { hidden: true }) }
    end

    def recording_studio_user_provider_logo(provider)
      options = RecordingStudioUser.config.omniauth_providers[provider.to_sym] || {}
      configured = options[:logo].presence || options["logo"].presence
      return configured if configured.present?

      RecordingStudioUser::Omniauth.default_logo(provider)
    end

    private

    def provider_logo_svg_mark(logo)
      content_tag(
        :span,
        logo.html_safe,
        class: "inline-flex h-8 w-8 shrink-0 items-center justify-center",
        aria: { hidden: true }
      )
    end
  end
end
