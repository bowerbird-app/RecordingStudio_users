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
      user.respond_to?(:identity_for) && user.identity_for(:google_oauth2).present?
    end

    def recording_studio_user_provider_label(provider)
      RecordingStudioUser::Omniauth.provider_label(provider)
    end
  end
end
