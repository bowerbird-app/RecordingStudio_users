# frozen_string_literal: true

RecordingStudioUsers.configure do |config|
  config.current_actor_resolver = ->(controller:) { controller.current_user }
  config.authentication_redirect = ->(controller:) { controller.main_app.new_user_session_path }
  config.after_role_switch_redirect = ->(controller:) { controller.main_app.root_path }
  config.layout = "application"
  config.root_scope_key = "workspaces"

  # Replace Workspace with your declared, owned root recordable.
  config.root_creator = lambda do |name:, **|
    Workspace.create!(name: name)
  end
end

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = ["User"]
  config.access_management_current_actor_resolver = ->(controller:) { controller.current_user }
  config.access_management_actor_email_resolver = lambda do |email:, **|
    User.find_by(email: email.to_s.strip.downcase)
  end
  config.access_management_missing_actor_handler = lambda do |email:, recording:, role:, **|
    {
      status: :requires_resolution,
      location: RecordingStudioUsers::Engine.routes.url_helpers.invitations_path(
        root_recording_id: recording.id,
        email: email,
        role: role
      ),
      notice: "Send an invitation to add this person."
    }
  end
end

RecordingStudioRootSwitchable.configure do |config|
  config.page_copy = {
    empty_state_title: "Set up your workspace",
    empty_state_body: "Create your first workspace, then you can switch between them here."
  }
end
