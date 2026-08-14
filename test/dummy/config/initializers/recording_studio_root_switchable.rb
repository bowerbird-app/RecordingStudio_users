# frozen_string_literal: true

RecordingStudioRootSwitchable.configure do |config|
  config.current_actor_resolver = lambda do |controller:|
    Current.actor || controller.current_user
  end

  # Render the mounted switcher pages inside the app shell when users visit them.
  config.layout = :application_layout

  config.after_switch_redirect = lambda do |controller:, return_to:, **|
    candidate_path = return_to.presence
    candidate_path = controller.main_app.root_path if candidate_path.blank?

    if internal_route?(candidate_path)
      candidate_path
    else
      controller.main_app.root_path
    end
  end

  config.scope :roots do |scope|
    scope.label = "My workspace"
    scope.description = "Roots the signed-in user is allowed to use."
    scope.available_roots = lambda do |actor:, **|
      (Workspace.order(:name).to_a + AdminRoot.order(:name).to_a).filter_map do |recordable|
        recording = RecordingStudio.root_recording_for(recordable)
        recording if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)
      end
    end
    scope.access_check = ->(actor:, **_) { actor.present? }

    scope.default_root = lambda do |roots:, **|
      roots.first
    end
  end
end

def internal_route?(path)
  routes = [
    Rails.application.routes,
    RecordingStudioRootSwitchable::Engine.routes
  ]

  routes.any? do |route_set|
    route_set.recognize_path(path, method: :get)
    true
  rescue StandardError
    false
  end
end
