# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User" ]
  config.access_actor_types += [ "RecordingStudioApi::ApiClient" ]
  config.access_management_actor_scope = ->(_controller) { User.all }
  config.admin_root_resolver = lambda do |**|
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    RecordingStudio.root_recording_for(admin_root)
  end
end
