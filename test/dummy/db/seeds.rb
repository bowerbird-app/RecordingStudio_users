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

bootstrap_owner_access = lambda do |actor, recording|
  result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
  raise result.error if result.failure?
end

seed_user = lambda do |email:, first_name:, last_name:, time_zone:, created_at: nil|
  user = User.find_or_initialize_by(email: email)
  user.password = user.password_confirmation = "Password" if user.new_record?
  if created_at && user.new_record?
    user.created_at = created_at
    user.updated_at = created_at
  end
  user.save! if user.new_record? || user.changed?

  if RecordingStudioUser.profile_for(user).nil?
    RecordingStudioUser.record_profile!(
      user,
      first_name: first_name,
      last_name: last_name,
      time_zone: time_zone,
      actor: user
    )
  end

  user
end

# Email-code account. Password accounts never get login codes, so OTP sign-in
# needs its own confirmed user to test against.
seed_otp_user = lambda do |email:, first_name:, last_name:, time_zone:|
  user = User.find_or_initialize_by(email: email)
  user.authentication_method = "otp"
  user.skip_confirmation! if user.respond_to?(:skip_confirmation!) && !user.confirmed?
  user.save! if user.new_record? || user.changed?

  if RecordingStudioUser.profile_for(user).nil?
    RecordingStudioUser.record_profile!(
      user,
      first_name: first_name,
      last_name: last_name,
      time_zone: time_zone,
      actor: user
    )
  end

  user
end

previous_actor = Current.actor

begin
  user = seed_user.call(
    email: "admin@admin.com",
    first_name: "Avery",
    last_name: "Admin",
    time_zone: "UTC"
  )
  user.update!(authentication_method: "password", confirmed_at: user.confirmed_at || Time.current)
  Current.actor = user

  avery_photo = Rails.root.join("db/seeds/avery-admin.png")
  File.open(avery_photo, "rb") do |io|
    RecordingStudioUser.attach_profile_image!(
      user,
      io: io,
      filename: "avery-admin.png",
      content_type: "image/png",
      actor: user
    )
  end

  seed_user.call(
    email: "member@admin.com",
    first_name: "Morgan",
    last_name: "Member",
    time_zone: "Eastern Time (US & Canada)"
  )

  otp_user = seed_otp_user.call(
    email: "otp@admin.com",
    first_name: "Ollie",
    last_name: "Otp",
    time_zone: "UTC"
  )

  seed_start = Date.current - 89.days

  200.times do |index|
    day_offset = case index
    when 0...100
      index % 10
    when 100...150
      20 + ((index - 100) % 20)
    else
      60 + ((index - 150) % 10)
    end
    created_at = (seed_start + day_offset.days).beginning_of_day + (index % 3600).seconds

    seed_user.call(
      email: "dummy_user_#{index + 1}@example.com",
      first_name: "Dummy",
      last_name: "User #{index + 1}",
      time_zone: "UTC",
      created_at: created_at
    )
  end

  # Create the workspace recordables
  workspace = Workspace.find_or_create_by!(name: "My workspace")
  accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
  private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
  folder = Folder.find_or_create_by!(name: "Product Docs")
  page = Page.find_or_create_by!(title: "Getting Started")

  # Create the root recording
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)

  find_or_record_child.call(page, root_recording, folder_recording)

  admin_root = AdminRoot.find_or_create_by!(name: "Admin")
  admin_root_recording = RecordingStudio.root_recording_for(admin_root)

  bootstrap_owner_access.call(user, admin_root_recording)
  bootstrap_owner_access.call(user, root_recording)
  bootstrap_owner_access.call(user, accessible_root_recording)

  RecordingStudioNotifications.notify(
    notification_type: :generic,
    recipient: user,
    title: "You're in",
    body: "This is the dummy inbox. OTP codes still land in Letters.",
    url: "/",
    channels: [:in_app],
    idempotency_key: "dummy-seed-welcome-#{user.id}"
  )
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: member@admin.com / Password"
puts "Seeded: #{otp_user.email} signs in with an email code (no password)"
puts "Seeded: Workspace '#{workspace.name}' with first-owner admin access and root recording ##{root_recording.id}"
puts "Seeded: Admin root with first-owner admin access for users reporting"
puts "Seeded: Workspace '#{accessible_workspace.name}' with first-owner admin access and root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' without admin access and root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
puts "Seeded: shared People root with Profile snapshots for seeded users"
puts "Seeded: Avery Admin profile photo on their Profile recording"
