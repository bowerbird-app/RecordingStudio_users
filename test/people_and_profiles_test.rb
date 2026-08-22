# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "test_helper"
require_relative "dummy/config/environment"

require "rails/test_help"

class PeopleAndProfilesEngineTest < ActiveSupport::TestCase
  test "People is a shared root and Profile is its only declared child" do
    assert RecordingStudio.validate_recordable_declarations!

    people = RecordingStudio.recordable_declaration_for("RecordingStudioUser::People")
    profile = RecordingStudio.recordable_declaration_for("RecordingStudioUser::Profile")

    assert people.root?
    assert people.shared?
    assert_equal "People", people.label
    assert_equal ["RecordingStudioUser::People"], RecordingStudioUser::Profile::ALLOWED_PARENT_TYPES
    assert_equal ["RecordingStudioUser::People"], profile.allowed_parent_types
    refute RecordingStudio.root_allowed?(User)
    refute_includes RecordingStudio.root_recordable_types, "User"
  end

  test "Accessible is enabled on Profile and not on People" do
    assert RecordingStudio.capability_enabled?(:accessible, for: RecordingStudioUser::Profile)
    refute RecordingStudio.capability_enabled?(:accessible, for: RecordingStudioUser::People)
  end

  test "Attachable is enabled on Profile and not on People" do
    assert RecordingStudio.capability_enabled?(:attachable, for: RecordingStudioUser::Profile)
    refute RecordingStudio.capability_enabled?(:attachable, for: RecordingStudioUser::People)
    assert_equal ["image/*"], RecordingStudioUser::Profile::ATTACHABLE_OPTIONS[:allowed_content_types]
    assert_equal %i[image], RecordingStudioUser::Profile::ATTACHABLE_OPTIONS[:enabled_attachment_kinds]
    assert_equal 1, RecordingStudioUser::Profile::ATTACHABLE_OPTIONS[:max_file_count]
  end

  test "directory bootstraps Profile first-owner and never People" do
    directory = File.read(RecordingStudioUser::Engine.root.join("lib/recording_studio_user/directory.rb"))
    access = File.read(RecordingStudioUser::Engine.root.join("lib/recording_studio_user/profile_access.rb"))

    assert_includes directory, "RecordingStudioAccessible.bootstrap_owner_access!("
    refute_includes directory, "bootstrap_owner_access!(recording: people_root"
    refute_includes directory, "access_management_authorizer"
    refute_includes access, "access_management_authorizer"
    refute_includes access, "grant_first_owner"
  end

  test "people_root.record creates Profile snapshots without raw recording inserts" do
    user = User.create!(
      email: "engine-profile-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )

    recording = RecordingStudioUser.people_root.record(RecordingStudioUser::Profile) do |profile|
      profile.user_id = user.id
      profile.first_name = "Engine"
      profile.last_name = "User"
      profile.time_zone = "UTC"
    end

    assert_equal "Engine", recording.recordable.first_name
    assert_equal RecordingStudioUser.people_root, recording.parent_recording
    assert_equal user.display_name, "Engine User"
  end
end
