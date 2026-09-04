# frozen_string_literal: true

require "recording_studio"
require "recording_studio_accessible"
require "recording_studio_admin"
require "recording_studio_attachable"
require "recording_studio_site_settings/version"
require "recording_studio_site_settings/engine"
require "recording_studio_site_settings/configuration"
require "recording_studio_site_settings/logo"

module RecordingStudioSiteSettings
  class Error < StandardError; end
  class Unauthorized < Error; end
end

require "recording_studio_site_settings/store"
require "recording_studio_site_settings/admin"

module RecordingStudioSiteSettings
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      sync_site_setting_parent_types!
    end

    def sync_site_setting_parent_types!(load_site_setting: false)
      const_get(:SiteSetting) if load_site_setting
      return unless const_defined?(:SiteSetting, false)

      SiteSetting.declare_hierarchy!
    rescue NameError
      nil
    end

    def name_for(root_recording)
      Store.name_for(root_recording)
    end

    def logo_for(root_recording, variant: :square_med)
      Store.logo_for(root_recording, variant: variant)
    end

    def square_logo_for(root_recording, variant: :square_med)
      Store.square_logo_for(root_recording, variant: variant)
    end

    def wide_logo_for(root_recording, variant: :small)
      Store.wide_logo_for(root_recording, variant: variant)
    end

    def favicon_for(root_recording, variant: :square_small)
      Store.favicon_for(root_recording, variant: variant)
    end

    def recording_for(root_recording)
      Store.recording_for(root_recording)
    end

    def settings_for(root_recording)
      Store.settings_for(root_recording)
    end

    def logo_recording_for(root_recording)
      Store.logo_recording_for(root_recording)
    end

    def square_logo_recording_for(root_recording)
      Store.square_logo_recording_for(root_recording)
    end

    def wide_logo_recording_for(root_recording)
      Store.wide_logo_recording_for(root_recording)
    end

    def favicon_recording_for(root_recording)
      Store.favicon_recording_for(root_recording)
    end

    def update!(...)
      Store.update!(...)
    end

    def site_root?(recording)
      Store.site_root?(recording)
    end

    def site_root_for(context)
      Store.site_root_for(context)
    end

    def admin_settings_path(context = nil)
      routes = context&.controller
      if routes.respond_to?(:recording_studio_site_settings)
        routes.recording_studio_site_settings.settings_path
      else
        Engine.routes.url_helpers.settings_path
      end
    end
  end
end
