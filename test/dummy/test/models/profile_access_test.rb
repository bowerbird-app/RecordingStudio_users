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

  test "create_user! bootstraps first-owner access on the Profile recording" do
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
    refute RecordingStudioAccessible.authorized?(
      actor: user,
      recording: RecordingStudioUser.people_root,
      role: :view
    )
  end

  test "record_profile! bootstraps missing owner access on an existing Profile recording" do
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

  test "People is not bootstrapped" do
    user = RecordingStudioUser.create_user!(
      email: "no-people-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "No",
      last_name: "People",
      time_zone: "UTC"
    )
    people_root = RecordingStudioUser.people_root
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: people_root, actor: user)

    assert result.failure?
    assert_equal(
      RecordingStudioAccessible::SharedRootAccess::GRANT_DENIED_MESSAGE,
      result.error.to_s
    )
    refute RecordingStudioAccessible.authorized?(actor: user, recording: people_root, role: :view)
    refute_includes File.read(RecordingStudioUser::Engine.root.join("lib/recording_studio_user/directory.rb")),
                    "bootstrap_owner_access!(recording: people_root"
    refute_includes File.read(RecordingStudioUser::Engine.root.join("lib/recording_studio_user/directory.rb")),
                    "bootstrap_owner_access!(recording: RecordingStudioUser.people_root"
  end

  test "first-owner path does not assign access_management_authorizer" do
    directory = File.read(RecordingStudioUser::Engine.root.join("lib/recording_studio_user/directory.rb"))
    access = File.read(RecordingStudioUser::Engine.root.join("lib/recording_studio_user/profile_access.rb"))

    assert_includes directory, "RecordingStudioAccessible.bootstrap_owner_access!("
    assert_includes directory, "recording: recording"
    assert_includes directory, "actor: user"
    refute_includes directory, "access_management_authorizer"
    refute_includes access, "access_management_authorizer"
    refute_includes directory, "AccessCreationContext"
    refute_includes access, "AccessCreationContext"
    refute_includes directory, "grant_first_owner"
    refute_includes access, "first_owner_retry?"
    refute_includes access, "AUTHORIZER_MUTEX"
    refute_includes access, "ensure_owner_access!"
  end

  test "a later extra actor uses grant_access with the owner as manager" do
    owner = RecordingStudioUser.create_user!(
      email: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Owner",
      last_name: "Person",
      time_zone: "UTC"
    )
    extra = RecordingStudioUser.create_user!(
      email: "extra-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Extra",
      last_name: "Person",
      time_zone: "UTC"
    )
    recording = RecordingStudioUser.profile_recording_for(owner)

    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: extra,
      role: :view,
      manager_actor: owner
    )

    assert result.success?
    assert RecordingStudioAccessible.authorized?(actor: extra, recording: recording, role: :view)
    refute RecordingStudioAccessible.authorized?(actor: extra, recording: recording, role: :admin)
    assert RecordingStudioUser::ProfileAccess.authorized?(extra, recording, role: :view)

    viewer = RecordingStudioUser.create_user!(
      email: "viewer-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Later",
      last_name: "Member",
      time_zone: "UTC"
    )
    RecordingStudioUser::ProfileAccess.grant_membership!(
      recording: recording,
      actor: viewer,
      role: :view,
      manager_actor: owner
    )

    assert RecordingStudioAccessible.authorized?(actor: viewer, recording: recording, role: :view)
    refute RecordingStudioAccessible.authorized?(actor: viewer, recording: recording, role: :admin)
  end

  test "grant_membership! raises when grant_access fails" do
    owner = RecordingStudioUser.create_user!(
      email: "raise-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Raise",
      last_name: "Owner",
      time_zone: "UTC"
    )
    extra = RecordingStudioUser.create_user!(
      email: "unauth-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "No",
      last_name: "Manager",
      time_zone: "UTC"
    )
    recording = RecordingStudioUser.profile_recording_for(owner)

    error = assert_raises(RuntimeError) do
      RecordingStudioUser::ProfileAccess.grant_membership!(
        recording: recording,
        actor: extra,
        role: :view,
        manager_actor: extra
      )
    end

    assert_match(/Not authorized to manage access/, error.message)
    refute RecordingStudioAccessible.authorized?(actor: extra, recording: recording, role: :view)
  end

  test "authorized? and role_for fail closed for blank actors or recordings" do
    user = RecordingStudioUser.create_user!(
      email: "blank-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Blank",
      last_name: "Check",
      time_zone: "UTC"
    )
    recording = RecordingStudioUser.profile_recording_for(user)

    refute RecordingStudioUser::ProfileAccess.authorized?(nil, recording, role: :view)
    refute RecordingStudioUser::ProfileAccess.authorized?(user, nil, role: :view)
    assert_nil RecordingStudioUser::ProfileAccess.role_for(nil, recording)
    assert_nil RecordingStudioUser::ProfileAccess.role_for(user, nil)
    assert_equal "admin", RecordingStudioUser::ProfileAccess.role_for(user, recording).to_s
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

  test "writes still go through record, revise, bootstrap, and grant_access" do
    directory = File.read(RecordingStudioUser::Engine.root.join("lib/recording_studio_user/directory.rb"))
    access = File.read(RecordingStudioUser::Engine.root.join("lib/recording_studio_user/profile_access.rb"))

    assert_includes directory, "people_root.record(Profile"
    assert_includes directory, "people_root.revise(recording"
    assert_includes directory, "RecordingStudioAccessible.bootstrap_owner_access!"
    assert_includes access, "RecordingStudioAccessible.grant_access"
    refute_includes access, "RecordingStudio::Access.create"
    refute_includes directory, "RecordingStudio::Recording.create"
    refute_includes directory, "RecordingStudio::Event.create"
  end
end
