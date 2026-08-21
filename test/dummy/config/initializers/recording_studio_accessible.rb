# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = ["User"]
  config.access_management_current_actor_resolver = ->(controller:) { controller.send(:current_user) }
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
      )
    }
  end
end
