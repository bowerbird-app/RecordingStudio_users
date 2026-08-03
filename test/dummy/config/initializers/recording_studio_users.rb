# frozen_string_literal: true

RecordingStudioUsers.configure do |config|
  config.current_actor_resolver = ->(controller:) { Current.actor || controller.current_user }
  config.current_root_resolver = ->(**) { RecordingStudio::RootSwitchable.current_root_recording }
  config.user_scope_resolver = ->(**) { User.order(:email) }
  config.layout = "flat_pack_sidebar"
end
