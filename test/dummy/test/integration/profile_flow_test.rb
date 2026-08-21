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

  test "profile routes do not accept a user id" do
    other = User.create!(
      email: "other-profile-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      first_name: "Other",
      last_name: "Person",
      time_zone: "UTC"
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

  test "a signed-in user views and updates only their own permitted profile fields" do
    sign_in @user

    get recording_studio_users.profile_path
    assert_response :success
    assert_select "title", text: "My Profile | Recording Studio User"
    assert_includes response.body, "Manage your personal details and account settings."
    assert_includes response.body, "Profile User"
    assert_select %(a[href="#{recording_studio_users.edit_profile_path}"]), text: "Edit", count: 1
    assert_select "dl.space-y-4", count: 1
    assert_includes response.body, "My profile"
    refute_includes response.body, "sm:grid-cols-2"
    assert_operator response.body.index(">Edit<"), :<, response.body.index(">Name<")

    get recording_studio_users.edit_profile_path
    assert_response :success
    assert_select "title", text: "Edit Profile | Recording Studio User"
    assert_includes response.body, "Update your personal information and contact details."
    assert_select "div[data-controller='flat-pack--select'][data-flat-pack--select-searchable-value='true']", count: 1
    assert_select "input[type='hidden'][name='user[time_zone]'][id='user_time_zone'][value='UTC'][required]", count: 1
    assert_select "div[role='option'][data-value='UTC']", count: 1
    assert_select "div[role='option'][data-value='Eastern Time (US & Canada)']", count: 1

    original_password = @user.encrypted_password

    patch recording_studio_users.profile_path, params: {
      user: {
        first_name: "Updated",
        last_name: "User",
        time_zone: "Eastern Time (US & Canada)",
        email: "ignored@example.com",
        password: "HackedPassword123!",
        id: SecureRandom.uuid
      }
    }

    assert_redirected_to recording_studio_users.profile_path
    follow_redirect!
    assert_includes response.body, "Profile updated."
    @user.reload
    assert_equal "Updated", @user.first_name
    assert_equal "Eastern Time (US & Canada)", @user.time_zone
    refute_equal "ignored@example.com", @user.email
    assert_equal original_password, @user.encrypted_password
  end

  test "invalid time zones re-render the form with feedback" do
    sign_in @user

    patch recording_studio_users.profile_path, params: {
      user: { first_name: "Updated", last_name: "User", time_zone: "Invalid/Zone" }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "prevented your profile from being saved"
    assert_equal "UTC", @user.reload.time_zone
  end

  test "configured additional profile attributes are permitted" do
    original_attributes = RecordingStudioUser.config.additional_profile_attributes
    RecordingStudioUser.config.additional_profile_attributes = [ :preferred_name ]

    controller = RecordingStudioUser::ProfilesController.new
    assert_includes controller.send(:permitted_profile_attributes), :preferred_name
    refute_includes controller.send(:permitted_profile_attributes), :email
    refute_includes controller.send(:permitted_profile_attributes), :password
  ensure
    RecordingStudioUser.config.additional_profile_attributes = original_attributes
  end

  test "profile updates do not create recordings or access items" do
    sign_in @user

    assert_no_difference -> { RecordingStudio::Recording.count } do
      assert_no_difference -> { RecordingStudio::Access.count } do
        patch recording_studio_users.profile_path, params: {
          user: { first_name: "No", last_name: "Recording", time_zone: "UTC" }
        }
      end
    end
  end

  test "switching roots does not change profile data" do
    sign_in @user
    workspace = Workspace.create!(name: "Profile Workspace")
    other_workspace = Workspace.create!(name: "Other Profile Workspace")
    source = RecordingStudio.root_recording_for(workspace)
    target = RecordingStudio.root_recording_for(other_workspace)
    bootstrap_owner_access!(@user, source)
    bootstrap_owner_access!(@user, target)

    patch recording_studio_users.profile_path, params: {
      user: { first_name: "Rootless", last_name: "Profile", time_zone: "UTC" }
    }
    assert_redirected_to recording_studio_users.profile_path

    switch_to(target)

    get recording_studio_users.profile_path
    assert_response :success
    assert_includes response.body, "Rootless Profile"
    @user.reload
    assert_equal "Rootless", @user.first_name
    assert_equal "Profile", @user.last_name
  end

  private

  def switch_to(root_recording)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "roots",
      root_switch: {
        root_recording_id: root_recording.id,
        return_to: "/"
      }
    }

    assert_redirected_to "/"
  end
end
