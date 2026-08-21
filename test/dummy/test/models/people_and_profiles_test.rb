# frozen_string_literal: true

require "test_helper"

class PeopleAndProfilesTest < ActiveSupport::TestCase
  test "People is a shared root labelled People" do
    declaration = RecordingStudio.recordable_declaration_for("RecordingStudioUser::People")

    assert RecordingStudio.validate_recordable_declarations!
    assert declaration.root?
    assert declaration.shared?
    assert_equal "People", declaration.label
    assert RecordingStudio.shared_root_type?("RecordingStudioUser::People")
    assert RecordingStudio.root_allowed?("RecordingStudioUser::People")
    assert_includes RecordingStudio.shared_root_types, "RecordingStudioUser::People"
  end

  test "Profile is allowed only under the People engine class name" do
    declaration = RecordingStudio.recordable_declaration_for("RecordingStudioUser::Profile")

    assert_equal ["RecordingStudioUser::People"], RecordingStudioUser::Profile::ALLOWED_PARENT_TYPES
    assert_equal ["RecordingStudioUser::People"], declaration.allowed_parent_types
    assert_equal ["RecordingStudioUser::People"], RecordingStudio.declared_parent_types_for("RecordingStudioUser::Profile")
    refute declaration.root?
    refute RecordingStudio.root_allowed?("RecordingStudioUser::Profile")
  end

  test "people_root.record writes a Profile snapshot instead of raw inserts" do
    user = User.create!(
      email: "profile-write-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )

    people_root = RecordingStudioUser.people_root
    recording_count = RecordingStudio::Recording.count
    event_count = RecordingStudio::Event.count
    profile_count = RecordingStudioUser::Profile.count

    recording = people_root.record(RecordingStudioUser::Profile) do |profile|
      profile.user_id = user.id
      profile.first_name = "Grace"
      profile.last_name = "Hopper"
      profile.time_zone = "UTC"
      profile.additional_profile_attributes = { "locale" => "en" }
    end

    profile = recording.recordable

    assert_equal recording_count + 1, RecordingStudio::Recording.count
    assert_equal event_count + 1, RecordingStudio::Event.count
    assert_equal profile_count + 1, RecordingStudioUser::Profile.count
    assert_equal user.id, profile.user_id
    assert_equal "Grace", profile.first_name
    assert_equal "Hopper", profile.last_name
    assert_equal "UTC", profile.time_zone
    assert_equal({ "locale" => "en" }, profile.additional_profile_attributes)
    assert_equal RecordingStudioUser.people_root, recording.parent_recording
    assert RecordingStudioUser.people_root.shared_root?
    assert recording.shared_root_tree?
  end

  test "revise creates a new Profile row instead of mutating in place" do
    user = RecordingStudioUser.create_user!(
      email: "revise-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Original",
      last_name: "Name",
      time_zone: "UTC"
    )
    original = RecordingStudioUser.profile_for(user)
    original_id = original.id
    recording = RecordingStudioUser.profile_recording_for(user)

    updated = RecordingStudioUser.record_profile!(
      user,
      first_name: "Revised",
      last_name: "Name",
      time_zone: "Eastern Time (US & Canada)"
    ).recordable

    original.reload

    refute_equal original_id, updated.id
    assert_equal "Original", original.first_name
    assert_equal "UTC", original.time_zone
    assert_equal "Revised", updated.first_name
    assert_equal "Eastern Time (US & Canada)", updated.time_zone
    assert_equal recording.id, RecordingStudioUser.profile_recording_for(user).id
    assert_equal updated.id, RecordingStudioUser.profile_for(user).id
    assert_equal "Revised Name", user.display_name
  end

  test "Profile is rejected under Workspace" do
    user = User.create!(
      email: "rejected-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    workspace_root = RecordingStudio.root_recording_for(Workspace.create!(name: "Not People #{SecureRandom.hex(4)}"))

    error = assert_raises(RecordingStudio::InvalidParent) do
      workspace_root.record(RecordingStudioUser::Profile) do |profile|
        profile.user_id = user.id
        profile.first_name = "No"
        profile.last_name = "Thanks"
        profile.time_zone = "UTC"
      end
    end

    assert_match(/RecordingStudioUser::Profile cannot be recorded under Workspace/, error.message)
  end

  test "create_user! signs up a Devise user then records a Profile under People" do
    user = RecordingStudioUser.create_user!(
      email: "signup-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Signed",
      last_name: "Up",
      time_zone: "UTC"
    )

    profile = RecordingStudioUser.profile_for(user)

    assert user.persisted?
    assert_not user.has_attribute?(:first_name)
    assert_equal "Signed", profile.first_name
    assert_equal "Up", profile.last_name
    assert_equal user.id, profile.user_id
    assert_equal RecordingStudioUser.people_root, RecordingStudioUser.profile_recording_for(user).parent_recording
  end
end
