# frozen_string_literal: true

RecordingStudioRootSwitchable.configure do |config|
  config.current_actor_resolver = lambda do |controller:|
    Current.actor || controller.current_user
  end

  # Render the mounted switcher pages inside the app shell when users visit them.
  # Root Switchable 0.11+ rejects the :application_layout symbol.
  config.layout = "recording_studio/default_layout"

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
    # Signed-in actors only see roots they can :view. A signed-out request still
    # lands on the signup workspace so the continue notice can resolve live Terms.
    scope.available_roots = lambda do |actor:, **|
      (Workspace.order(:name).to_a + AdminRoot.order(:name).to_a).filter_map do |recordable|
        recording = RecordingStudio.root_recording_for(recordable)
        next if recording.blank?
        next recording if actor.blank? && signup_workspace?(recordable)

        recording if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)
      end
    end
    scope.access_check = lambda do |actor:, recording: nil, **|
      if actor.blank?
        signup_workspace?(recording&.recordable)
      else
        recording.present? &&
          RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)
      end
    end

    scope.default_root = lambda do |roots:, **|
      roots.find { |root| signup_workspace?(root.recordable) } || roots.first
    end
  end
end

def signup_workspace?(recordable)
  recordable.try(:name) == Dummy::SignupTerms::WORKSPACE_NAME
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
