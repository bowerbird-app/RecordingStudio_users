# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ProfileFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "profile-flow-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  test "profiles require the existing Devise sign-in flow" do
    get recording_studio_users.profile_path

    assert_redirected_to new_user_session_path
  end

  test "profile routes do not accept a user id" do
    other = User.create!(
      email: "other-profile-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )

    sign_in @user

    get "#{recording_studio_users.profile_path}/#{other.id}"

    assert_response :not_found
  end

  test "the host does not expose unscoped profile helpers" do
    named_routes = Rails.application.routes.named_routes.names

    refute_includes named_routes, :profile
    refute_includes named_routes, :edit_profile
    assert_includes named_routes, :recording_studio_users
  end

  test "signup helper records a Profile and display_name reads it" do
    user = RecordingStudioUser.create_user!(
      email: "named-profile-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Profile",
      last_name: "User",
      time_zone: "UTC"
    )

    assert_equal "Profile User", user.display_name
    assert_equal "Profile", RecordingStudioUser.profile_for(user).first_name
    refute user.has_attribute?(:first_name)
  end
end
