# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  if config.respond_to?(:access_management_actor_scope=)
    config.access_management_actor_scope = ->(_controller) { User.all }
  elsif config.respond_to?(:access_actor_types=)
    config.access_actor_types = [ "User" ]
  end
end
