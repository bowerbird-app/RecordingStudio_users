# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ProfileFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "profile-flow-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      first_name: "Profile",
      last_name: "User",
      time_zone: "UTC"
    )
  end

  test "profiles require the existing Devise sign-in flow" do
    get recording_studio_users.profile_path

    assert_redirected_to new_user_session_path
  end

  test "a signed-in user views and updates only their own permitted profile fields" do
    sign_in @user

    get recording_studio_users.profile_path
    assert_response :success
    assert_includes response.body, "Profile User"
    assert_select %(a[aria-label="Home"][href="/"]), count: 1
    refute_includes response.body, "flat-pack-sidebar"

    patch recording_studio_users.profile_path, params: {
      user: {
        first_name: "Updated",
        last_name: "User",
        time_zone: "Eastern Time (US & Canada)",
        email: "ignored@example.com",
        id: SecureRandom.uuid
      }
    }

    assert_redirected_to recording_studio_users.profile_path
    @user.reload
    assert_equal "Updated", @user.first_name
    assert_equal "Eastern Time (US & Canada)", @user.time_zone
    refute_equal "ignored@example.com", @user.email
  end

  test "profile updates do not create recordings" do
    sign_in @user

    assert_no_difference -> { RecordingStudio::Recording.count } do
      patch recording_studio_users.profile_path, params: {
        user: { first_name: "No", last_name: "Recording", time_zone: "UTC" }
      }
    end
  end
end
