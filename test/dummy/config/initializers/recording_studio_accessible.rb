# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User", "RecordingStudioApi::ApiClient" ]
  config.access_management_actor_scope = ->(_controller) { User.all }
end
