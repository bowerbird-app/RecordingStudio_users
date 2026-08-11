# frozen_string_literal: true

admin_email = ENV.fetch("DUMMY_ADMIN_EMAIL", "admin@example.com")
admin_password = ENV.fetch("DUMMY_ADMIN_PASSWORD", "Password123!")
user_email = ENV.fetch("DUMMY_USER_EMAIL", "user@example.com")
user_password = ENV.fetch("DUMMY_USER_PASSWORD", "Password123!")

admin_user = User.find_or_initialize_by(email: admin_email)
admin_user.assign_attributes(
  first_name: "Avery",
  last_name: "Admin",
  time_zone: "Australia/Sydney",
  password: admin_password,
  password_confirmation: admin_password
)
admin_user.save!

normal_user = User.find_or_initialize_by(email: user_email)
normal_user.assign_attributes(
  first_name: "Morgan",
  last_name: "Member",
  time_zone: "Pacific Time (US & Canada)",
  password: user_password,
  password_confirmation: user_password
)
normal_user.save!

workspace = Workspace.find_or_create_by!(name: "My workspace")
admin_root = AdminRoot.find_or_create_by!(name: "Admin")

previous_actor = Current.actor
previous_authorizer = RecordingStudioAccessible.configuration.access_management_authorizer
Current.actor = admin_user
RecordingStudioAccessible.configuration.access_management_authorizer = ->(recording:, **) { recording.present? }

begin
  workspace_recording = RecordingStudio.root_recording_for(workspace)
  admin_recording = RecordingStudio.root_recording_for(admin_root)

  unless RecordingStudioAccessible.authorized?(actor: admin_user, recording: admin_recording, role: :admin)
    result = RecordingStudioAccessible.grant_access(
      recording: admin_recording,
      actor: admin_user,
      role: :admin,
      manager_actor: admin_user
    )
    raise "Unable to grant dummy admin access: #{result.error}" if result.failure?
  end
ensure
  RecordingStudioAccessible.configuration.access_management_authorizer = previous_authorizer
  Current.actor = previous_actor
end

puts "Seeded users: #{admin_user.email}, #{normal_user.email}"
puts "Set DUMMY_ADMIN_PASSWORD and DUMMY_USER_PASSWORD to override development passwords."
puts "Seeded roots: #{workspace.name}, #{admin_root.name}"
