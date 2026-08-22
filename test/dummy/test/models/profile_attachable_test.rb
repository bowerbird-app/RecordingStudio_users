# frozen_string_literal: true

require "test_helper"

class ProfileAttachableTest < ActiveSupport::TestCase
  include ProfileImageTestHelper

  test "Attachable is enabled on Profile only with one-image options" do
    options = RecordingStudio.capability_options(:attachable, for_type: "RecordingStudioUser::Profile")

    assert RecordingStudio.capability_enabled?(:attachable, for: "RecordingStudioUser::Profile")
    refute RecordingStudio.capability_enabled?(:attachable, for: "RecordingStudioUser::People")
    assert_equal ["image/*"], options[:allowed_content_types]
    assert_equal %i[image], options[:enabled_attachment_kinds]
    assert_equal 1, options[:max_file_count]
    refute_includes RecordingStudio.capability_allowed_parent_types_for("RecordingStudioAttachable::Attachment"),
                    "RecordingStudioUser::People"
  end

  test "attach_profile_image! records one attachment under the Profile recording" do
    user = RecordingStudioUser.create_user!(
      email: "photo-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Photo",
      last_name: "Owner",
      time_zone: "UTC"
    )
    profile_recording = RecordingStudioUser.profile_recording_for(user)

    first = attach_profile_photo!(user)
    second = attach_profile_photo!(user, filename: "again.png")

    assert_equal first.id, second.id
    assert_equal profile_recording.id, first.parent_recording_id
    assert_equal "RecordingStudioAttachable::Attachment", first.recordable_type
    assert_equal 1, profile_recording.images.to_a.size
    assert_equal first.id, RecordingStudioUser.profile_image_recording_for(user).id
  end

  test "People is not attachable" do
    people = File.read(RecordingStudioUser::Engine.root.join("app/models/recording_studio_user/people.rb"))

    refute_includes people, "Capabilities::Attachable"
    refute RecordingStudio.capability_enabled?(:attachable, for: RecordingStudioUser::People)
  end
end
