# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.access_recording_resolver = lambda do |context|
    RecordingStudioAccessible.admin_root(context: context)
  end
end
