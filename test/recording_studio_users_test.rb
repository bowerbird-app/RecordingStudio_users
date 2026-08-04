# frozen_string_literal: true

require "test_helper"

class RecordingStudioUsersTest < Minitest::Test
  PUBLIC_API = %i[
    configure configuration user_class provision provisioned? user_root_for
    user_root_recording_for profile_recording_for profile_for avatar_recording_for
    validate_user_profile! revise_profile upload_avatar replace_avatar remove_avatar
    log_user_event identity_visible? email_visible? profile_visible? profile_editable?
    display_name initials avatar_for profile_path_for profile_complete?
    preload_user_information search_users
  ].freeze

  def test_version_matches_release
    assert_equal "0.1.2", RecordingStudioUsers::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, RecordingStudioUsers::Engine
  end

  def test_public_api_is_available
    PUBLIC_API.each { |method| assert_respond_to RecordingStudioUsers, method }
  end

  def test_result_is_normalized
    dependency_result = Data.define(:success?, :value, :error, :errors).new(false, nil, "denied", ["private"])
    result = RecordingStudioUsers::Result.from_dependency(dependency_result)

    assert result.failure?
    assert_equal "denied", result.error
    assert_equal ["private"], result.errors
  end
end
