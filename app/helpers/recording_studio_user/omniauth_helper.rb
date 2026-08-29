# frozen_string_literal: true

module RecordingStudioUser
  module OmniauthHelper
    def recording_studio_user_google_oauth_configured?
      RecordingStudioUser.config.google_oauth2_configured?
    end

    def recording_studio_user_continue_with_google_path
      return unless recording_studio_user_google_oauth_configured?

      main_app.user_google_oauth2_omniauth_authorize_path
    end

    def recording_studio_user_google_connected?(user = (respond_to?(:current_user) ? current_user : nil))
      return false if user.nil?

      user.respond_to?(:identity_for) && user.identity_for(:google_oauth2).present?
    end

    def recording_studio_user_provider_label(provider)
      RecordingStudioUser::Omniauth.provider_label(provider)
    end

    # Flatpack List::Item can lead with an inline SVG via `icon:` or text/HTML via `leading:`.
    # It has no first-class image URL prop — configured logo URLs use `leading:` with an <img>.
    def recording_studio_user_provider_list_item_leading(provider)
      logo = recording_studio_user_provider_logo(provider)
      return {} if logo.blank?
      return { icon: logo } if logo.to_s.start_with?("<svg")

      { leading: image_tag(logo, alt: "", class: "h-8 w-8 shrink-0", aria: { hidden: true }) }
    end

    def recording_studio_user_provider_logo(provider)
      options = RecordingStudioUser.config.omniauth_providers[provider.to_sym] || {}
      configured = options[:logo].presence || options["logo"].presence
      return configured if configured.present?
      return RecordingStudioUser::Omniauth::GOOGLE_LOGO_SVG if provider.to_sym == :google_oauth2

      nil
    end
  end
end
