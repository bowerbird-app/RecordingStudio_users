# frozen_string_literal: true

require "test_helper"

class ProfileAccessTest < ActiveSupport::TestCase
  test "Accessible is enabled on Profile and not on People" do
    assert RecordingStudio.capability_enabled?(:accessible, for: "RecordingStudioUser::Profile")
    refute RecordingStudio.capability_enabled?(:accessible, for: "RecordingStudioUser::People")
    assert_includes RecordingStudio.capability_allowed_parent_types_for("RecordingStudio::Access"),
                    "RecordingStudioUser::Profile"
    refute_includes RecordingStudio.capability_allowed_parent_types_for("RecordingStudio::Access"),
                    "RecordingStudioUser::People"
  end

  test "create_user! grants the owner Accessible admin on the Profile recording" do
    user = RecordingStudioUser.create_user!(
      email: "granted-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Granted",
      last_name: "Owner",
      time_zone: "UTC"
    )
    recording = RecordingStudioUser.profile_recording_for(user)

    assert RecordingStudioAccessible.authorized?(actor: user, recording: recording, role: :admin)
    assert RecordingStudioUser::ProfileAccess.authorized?(user, recording, role: :edit)
    assert_equal "admin", RecordingStudioAccessible.role_for(actor: user, recording: recording).to_s
  end

  test "record_profile! grants missing owner access on an existing Profile recording" do
    user = User.create!(
      email: "upgrade-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    recording = RecordingStudioUser.people_root.record(RecordingStudioUser::Profile) do |profile|
      profile.user_id = user.id
      profile.first_name = "Before"
      profile.last_name = "Grant"
      profile.time_zone = "UTC"
    end

    refute RecordingStudioAccessible.authorized?(actor: user, recording: recording, role: :view)

    RecordingStudioUser.record_profile!(user, first_name: "After", last_name: "Grant", time_zone: "UTC")
    recording.reload

    assert RecordingStudioAccessible.authorized?(actor: user, recording: recording, role: :admin)
    assert_equal "After", RecordingStudioUser.profile_for(user).first_name
  end

  test "other users are denied on a Profile recording" do
    owner = RecordingStudioUser.create_user!(
      email: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Owner",
      last_name: "Person",
      time_zone: "UTC"
    )
    stranger = RecordingStudioUser.create_user!(
      email: "stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Other",
      last_name: "Person",
      time_zone: "UTC"
    )
    recording = RecordingStudioUser.profile_recording_for(owner)

    refute RecordingStudioAccessible.authorized?(actor: stranger, recording: recording, role: :view)
    assert_nil RecordingStudioAccessible.role_for(actor: stranger, recording: recording)
    refute RecordingStudioUser::ProfileAccess.authorized?(stranger, recording, role: :view)
  end

  test "grant_access is rejected on the shared People root" do
    owner = RecordingStudioUser.create_user!(
      email: "people-root-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "People",
      last_name: "Root",
      time_zone: "UTC"
    )

    result = RecordingStudioAccessible.grant_access(
      recording: RecordingStudioUser.people_root,
      actor: owner,
      role: :view,
      manager_actor: owner
    )

    assert result.failure?
    refute RecordingStudioAccessible.authorized?(actor: owner, recording: RecordingStudioUser.people_root, role: :view)
  end

  test "writes still go through record, revise, and grant_access" do
    directory = File.read(RecordingStudioUser::Engine.root.join("lib/recording_studio_user/directory.rb"))
    access = File.read(RecordingStudioUser::Engine.root.join("lib/recording_studio_user/profile_access.rb"))

    assert_includes directory, "people_root.record(Profile"
    assert_includes directory, "people_root.revise(recording"
    assert_includes directory, "ProfileAccess.ensure_owner_access!"
    assert_includes access, "RecordingStudioAccessible.grant_access"
    refute_includes access, "RecordingStudio::Access.create"
    refute_includes directory, "RecordingStudio::Recording.create"
    refute_includes directory, "RecordingStudio::Event.create"
  end
end
