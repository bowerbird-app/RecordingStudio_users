# frozen_string_literal: true

RecordingStudioSiteSettings.configure do |config|
  # Dummy proves Accessible inheritance from the admin root, matching the
  # site_settings gem dummy. Hosts usually keep Workspace as the site root.
  config.site_root_types = ["AdminRoot"]
end
