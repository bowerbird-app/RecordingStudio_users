# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class LayoutConfigurationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = RecordingStudioUser.create_user!(
      email: "layout-config-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Layout",
      last_name: "User",
      time_zone: "UTC"
    )
    accept_pending_live_terms!(@user)
    sign_in @user
    @user_layout = RecordingStudioUser.configuration.layout
    @core_layout = RecordingStudio.configuration.layout
  end

  teardown do
    RecordingStudioUser.configuration.layout = @user_layout
    RecordingStudio.configuration.layout = @core_layout
  end

  test "nil layout falls through to the core layout and then the default template" do
    RecordingStudioUser.configuration.layout = nil
    RecordingStudio.configuration.layout = "application"

    get recording_studio_users.profile_path

    assert_response :success
    assert_select %(body[data-recording-studio-default-layout="true"]), count: 0

    RecordingStudio.configuration.layout = nil

    get recording_studio_users.profile_path

    assert_response :success
    assert_select %(body[data-recording-studio-default-layout="true"]), count: 1
    assert_select "h1", text: "My Profile", count: 1
  end

  test "a string layout name selects that layout" do
    RecordingStudioUser.configuration.layout = "application"

    get recording_studio_users.profile_path

    assert_response :success
    assert_select %(body[data-recording-studio-default-layout="true"]), count: 0
    assert_includes response.body, "My Profile"
  end

  test "false renders the profile without a layout" do
    RecordingStudioUser.configuration.layout = false

    get recording_studio_users.profile_path

    assert_response :success
    assert_select %(body[data-recording-studio-default-layout="true"]), count: 0
    assert_includes response.body, "Layout User"
  end

  test "a keyword layout callable receives the controller" do
    seen = nil
    RecordingStudioUser.configuration.layout = lambda { |controller:|
      seen = controller
      "application"
    }

    get recording_studio_users.profile_path

    assert_response :success
    assert_equal "RecordingStudioUser::ProfilesController", seen.class.name
    assert_select %(body[data-recording-studio-default-layout="true"]), count: 0
  end
end
