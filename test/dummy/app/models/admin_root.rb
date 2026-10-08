class AdminRoot < ApplicationRecord
  include RecordingStudioAdmin::AllowsAdminSections

  recording_studio_recordable label: "Admin", root: true
  RecordingStudio.enable_capability(:accessible, on: self)
  RecordingStudio.enable_capability(:api_access_point, on: self) if defined?(RecordingStudioApi)

  recording_studio_admin_sections do
    section :root
    section :users
    section :site_settings
  end
end
