# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ProfileFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ProfileImageTestHelper

  setup do
    @user = RecordingStudioUser.create_user!(
      email: "profile-flow-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
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
    other = RecordingStudioUser.create_user!(
      email: "other-profile-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Other",
      last_name: "User",
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

  test "signup helper records a Profile and display_name reads it" do
    assert_equal "Profile User", @user.display_name
    assert_equal "Profile", RecordingStudioUser.profile_for(@user).first_name
    refute @user.has_attribute?(:first_name)
  end

  test "signed-in owners can show and edit their Accessible Profile" do
    sign_in @user

    get recording_studio_users.profile_path

    assert_response :success
    assert_includes response.body, "Profile User"
    assert_includes response.body, "UTC"
    refute_includes response.body, "can_access?"

    get recording_studio_users.edit_profile_path

    assert_response :success
    assert_includes response.body, "Profile"
    assert_includes response.body, "User"
  end

  test "profile update revises the Profile snapshot instead of User columns" do
    sign_in @user
    recording = RecordingStudioUser.profile_recording_for(@user)
    original_profile_id = RecordingStudioUser.profile_for(@user).id

    patch recording_studio_users.profile_path, params: {
      user: { first_name: "Revised", last_name: "Name", time_zone: "Eastern Time (US & Canada)" }
    }

    assert_redirected_to recording_studio_users.profile_path
    follow_redirect!
    assert_response :success
    assert_includes Nokogiri::HTML(response.body).text, "Revised Name"
    assert_includes Nokogiri::HTML(response.body).text, "Eastern Time (US & Canada)"
    assert_equal recording.id, RecordingStudioUser.profile_recording_for(@user).id
    refute_equal original_profile_id, RecordingStudioUser.profile_for(@user).id
    refute @user.reload.has_attribute?(:first_name)
  end

  test "signed-in users without an Accessible grant are forbidden" do
    locked_out = User.create!(
      email: "locked-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    RecordingStudioUser.people_root.record(RecordingStudioUser::Profile) do |profile|
      profile.user_id = locked_out.id
      profile.first_name = "Locked"
      profile.last_name = "Out"
      profile.time_zone = "UTC"
    end

    sign_in locked_out
    get recording_studio_users.profile_path

    assert_response :forbidden
  end

  test "profile show does not render notice or flash itself" do
    show = File.read(RecordingStudioUser::Engine.root.join("app/views/recording_studio_user/profiles/show.html.erb"))

    refute_includes show, "notice"
    refute_includes show, "flash"
    refute_includes show, "FlatPack::Alert::Component"
  end

  test "profile show uses default layout chrome with one flash and an empty access slot" do
    recording = RecordingStudioUser.profile_recording_for(@user)

    get recording_studio_users.profile_path
    assert_redirected_to new_user_session_path

    post user_session_path, params: {
      user: { email: @user.email, password: "Password123!" }
    }
    follow_redirect!

    assert_response :success
    assert_equal recording_studio_users.profile_path, path
    assert_select %(body[data-recording-studio-default-layout="true"]), count: 1
    assert_select %(body[data-theme="rounded"]), count: 1
    assert_select "html[data-theme]", count: 0
    assert_equal 1, response.body.scan("Signed in successfully.").size
    assert_select %(a[href="#{recording_studio_accessible.recording_accesses_path(recording)}"]), count: 0
    refute_includes response.body, "Manage access"
    refute_includes response.body, "Sign out"
    refute_includes response.body, "Root Switchable"
    refute_includes response.body, "flat-pack-sidebar-layout"
    assert_includes response.body, "Add a photo"
    assert_includes response.body, recording_studio_attachable.recording_attachment_upload_path(recording)
    refute File.exist?(Rails.root.join("app/views/layouts/recording_studio/default_layout.html.erb"))
  end

  test "profile edit uses the same default layout chrome" do
    sign_in @user
    recording = RecordingStudioUser.profile_recording_for(@user)

    get recording_studio_users.edit_profile_path

    assert_response :success
    assert_select %(body[data-recording-studio-default-layout="true"]), count: 1
    assert_select %(body[data-theme="rounded"]), count: 1
    assert_select %(a[href="#{recording_studio_accessible.recording_accesses_path(recording)}"]), count: 0
    refute_includes response.body, "Manage access"
    refute_includes response.body, "Sign out"
    refute_includes response.body, "Root Switchable"
    refute_includes response.body, "flat-pack-sidebar-layout"
    assert_includes response.body, "Add a photo"
    assert_includes response.body, recording_studio_attachable.recording_attachment_upload_path(recording)
  end

  test "profile show and edit display one attached image and a replace path" do
    sign_in @user
    recording = RecordingStudioUser.profile_recording_for(@user)
    image = attach_profile_photo!(@user)

    get recording_studio_users.profile_path

    assert_response :success
    assert_includes response.body, "Swap this photo"
    refute_includes response.body, "Add a photo"
    assert_includes response.body, recording_studio_attachable.attachment_path(image)
    assert(
      response.body.include?(recording_studio_attachable.attachment_preview_file_path(image, variant_name: :square_med)) ||
        response.body.include?(recording_studio_attachable.attachment_file_path(image))
    )
    refute_includes response.body, recording_studio_attachable.recording_attachments_path(recording)
    refute_includes response.body, "Manage access"

    get recording_studio_users.edit_profile_path

    assert_response :success
    assert_includes response.body, "Swap this photo"
    assert_includes response.body, recording_studio_attachable.attachment_path(image)
    refute_includes response.body, "Manage access"
  end

  test "a current_user-only ACL is not used for profile authorization" do
    controller = File.read(RecordingStudioUser::Engine.root.join("app/controllers/recording_studio_user/profiles_controller.rb"))

    assert_includes controller, "RecordingStudioAccessible.authorized?"
    assert_includes controller, "authorize_profile_access!"
    refute_includes controller, "can_access?"
    refute_includes controller, "@user.update"
    refute_includes controller, "current_user.admin"
    refute_includes controller, "user.admin?"
  end
end
