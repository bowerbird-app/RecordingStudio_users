# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.access_recording_resolver = lambda do |_context|
    admin_root = AdminRoot.find_by(name: "Admin")
    RecordingStudio.root_recording_for(admin_root) if admin_root
  end
  config.site_admin_recording_resolver = config.access_recording_resolver
end
