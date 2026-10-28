# frozen_string_literal: true

require "digest/md5"
require "test_helper"

class ProfileAttachableTest < ActiveSupport::TestCase
  include ProfileImageTestHelper

  test "Attachable is enabled on Profile only with one-image options" do
    options = RecordingStudio.capability_options(:attachable, for_type: "RecordingStudioUser::Profile")
    types = RecordingStudio.configuration.recordable_types.map(&:to_s)

    assert RecordingStudio.capability_enabled?(:attachable, for: "RecordingStudioUser::Profile")
    refute RecordingStudio.capability_enabled?(:attachable, for: "RecordingStudioUser::People")
    assert_equal [ "image/*" ], options[:allowed_content_types]
    assert_equal %i[image], options[:enabled_attachment_kinds]
    assert_equal 1, options[:max_file_count]
    refute_includes RecordingStudio.capability_allowed_parent_types_for("RecordingStudioAttachable::Attachment"),
                    "RecordingStudioUser::People"
    refute_includes types, "RecordingStudioAttachable::Library"
    refute_includes types, "RecordingStudioAttachable::Placement"
    refute RecordingStudio.capability_enabled?(:image_library, for: "RecordingStudioUser::Profile")
    refute RecordingStudio.capability_enabled?(:library_placement, for: "RecordingStudioUser::Profile")
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

  test "replace_profile_image! swaps the file on the same attachment recording" do
    user = RecordingStudioUser.create_user!(
      email: "swap-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Swap",
      last_name: "Owner",
      time_zone: "UTC"
    )
    first = attach_profile_photo!(user)

    File.open(profile_photo_fixture_path, "rb") do |io|
      swapped = RecordingStudioUser.replace_profile_image!(
        user,
        io: io,
        filename: "swapped.png",
        content_type: "image/png",
        actor: user
      )
      assert_equal first.id, swapped.id
    end

    current = RecordingStudioUser.profile_image_recording_for(user)
    assert_equal first.id, current.id
    assert_equal "swapped.png", current.recordable.original_filename
  end

  test "assign_profile_image! attaches then replaces a signed upload, and remove_profile_image! clears it" do
    user = RecordingStudioUser.create_user!(
      email: "signed-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Signed",
      last_name: "Owner",
      time_zone: "UTC"
    )
    recording = RecordingStudioUser.profile_recording_for(user)
    first = issued_profile_blob!(recording, user, filename: "first.png")
    assigned = RecordingStudioUser.assign_profile_image!(
      user,
      signed_blob_id: RecordingStudioAttachable::DirectUpload.sign(first),
      actor: user
    )

    assert_equal "first.png", assigned.recordable.original_filename
    assert_equal recording.id, assigned.parent_recording_id

    second = issued_profile_blob!(recording, user, filename: "second.png")
    replaced = RecordingStudioUser.assign_profile_image!(
      user,
      signed_blob_id: RecordingStudioAttachable::DirectUpload.sign(second),
      actor: user
    )

    assert_equal assigned.id, replaced.id
    assert_equal "second.png", RecordingStudioUser.profile_image_recording_for(user).recordable.original_filename

    RecordingStudioUser.remove_profile_image!(user, actor: user)

    assert_nil RecordingStudioUser.profile_image_recording_for(user)
  end

  test "People is not attachable" do
    refute RecordingStudio.capability_enabled?(:attachable, for: RecordingStudioUser::People)
  end

  test "replace_profile_image! authorizes the actor through Attachable" do
    owner = RecordingStudioUser.create_user!(
      email: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Owner",
      last_name: "Photo",
      time_zone: "UTC"
    )
    stranger = RecordingStudioUser.create_user!(
      email: "stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Other",
      last_name: "Person",
      time_zone: "UTC"
    )
    attach_profile_photo!(owner)

    error = assert_raises(RecordingStudioAttachable::Authorization::NotAuthorizedError) do
      File.open(profile_photo_fixture_path, "rb") do |io|
        RecordingStudioUser.replace_profile_image!(
          owner,
          io: io,
          filename: "stolen.png",
          content_type: "image/png",
          actor: stranger
        )
      end
    end

    assert_match(/Not authorized to upload/, error.message)
    assert_equal "profile.png", RecordingStudioUser.profile_image_recording_for(owner).recordable.original_filename
  end

  private

  def issued_profile_blob!(recording, actor, filename:)
    bytes = File.binread(profile_photo_fixture_path)
    blob = RecordingStudioAttachable::DirectUpload.prepare!(
      recording: recording,
      actor: actor,
      filename: filename,
      byte_size: bytes.bytesize,
      checksum: Digest::MD5.base64digest(bytes),
      content_type: "image/png"
    )
    blob.upload(StringIO.new(bytes), identify: false)
    blob
  end
end
