# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.access_recording_resolver = lambda do |_context|
    admin_root = AdminRoot.find_by(name: "Admin")
    RecordingStudio::Recording.find_by(recordable: admin_root, trashed_at: nil) if admin_root
  end
  config.site_admin_recording_resolver = config.access_recording_resolver
  config.engine_layout = "flat_pack_sidebar"
end

Rails.application.config.to_prepare do
  DummyAdmin.register!
  RecordingStudioUser.register_admin!
end
