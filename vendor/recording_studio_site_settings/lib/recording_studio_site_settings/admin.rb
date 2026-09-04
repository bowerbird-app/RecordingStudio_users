# frozen_string_literal: true

require "recording_studio_admin"

module RecordingStudioSiteSettings
  module Admin
    class SiteSettingsSection < RecordingStudioAdmin::Section
      key "site_settings"
      icon :photo
      title "Site"
      subtitle "Name, logos, and the browser tab icon."
      blast_radius :site

      link :edit,
           text: "Edit site settings",
           url: ->(context) { RecordingStudioSiteSettings.admin_settings_path(context) },
           style: :primary
    end

    class SiteSettingsResource < RecordingStudioAdmin::Resource
      key "site_settings"
      section "site_settings"
      title "Site name and logos"

      action :show,
             text: "Site name and logos",
             icon: "photo",
             url: ->(_row, context) { RecordingStudioSiteSettings.admin_settings_path(context) }

      action :edit,
             text: "Save",
             icon: "pencil-square",
             required_role: :admin,
             url: ->(_row, context) { RecordingStudioSiteSettings.admin_settings_path(context) }
    end

    def self.register!
      RecordingStudioAdmin.register_section(SiteSettingsSection)
      RecordingStudioAdmin.register_resource(SiteSettingsResource)
    end
  end
end
