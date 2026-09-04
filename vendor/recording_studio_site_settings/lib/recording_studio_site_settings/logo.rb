# frozen_string_literal: true

module RecordingStudioSiteSettings
  Logo = Data.define(:recording, :preview_url, :filename) do
    def present?
      recording.present?
    end

    def blank?
      recording.blank?
    end
  end

  Favicon = Logo
end
