# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

# Create normal users with the profile fields required by the host contract.
user = User.find_or_initialize_by(email: "admin@admin.com")
user.assign_attributes(first_name: "Avery", last_name: "Admin", time_zone: "UTC")
user.password = user.password_confirmation = "Password" if user.new_record?
user.save! if user.changed?

member = User.find_or_initialize_by(email: "member@admin.com")
member.assign_attributes(first_name: "Morgan", last_name: "Member", time_zone: "Eastern Time (US & Canada)")
member.password = member.password_confirmation = "Password" if member.new_record?
member.save! if member.changed?

# Create the workspace recordables
workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")

previous_actor = Current.actor
Current.actor = user

begin
  # Create the root recording
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)

  find_or_record_child.call(page, root_recording, folder_recording)
ensure
  Current.actor = previous_actor
end

admin_root = AdminRoot.find_or_create_by!(name: "Admin")
admin_root_recording = RecordingStudio.root_recording_for(admin_root)

unless RecordingStudioAccessible.authorized?(actor: user, recording: admin_root_recording, role: :admin)
  RecordingStudioAccessible::AccessCreationContext.allow do
    admin_root_recording.record(RecordingStudio::Access, parent_recording: admin_root_recording) do |access|
      access.actor = user
      access.role = :admin
    end
  end
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: member@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Admin root with access-controlled users reporting"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
