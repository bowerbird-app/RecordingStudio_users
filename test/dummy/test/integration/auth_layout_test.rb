# frozen_string_literal: true

require "test_helper"

class AuthLayoutTest < ActionDispatch::IntegrationTest
  AUTH_PAGES = [
    :new_user_session_path,
    :new_user_registration_path,
    :new_user_password_path,
    :new_user_confirmation_path
  ].freeze

  setup do
    @user_layout = RecordingStudioUser.configuration.layout
    @core_layout = RecordingStudio.configuration.layout
  end

  teardown do
    RecordingStudioUser.configuration.layout = @user_layout
    RecordingStudio.configuration.layout = @core_layout
  end

  test "signed-out auth screens resolve to core default layout" do
    AUTH_PAGES.each do |helper|
      get public_send(helper)

      assert_response :success, helper.to_s
      assert_select %(body[data-recording-studio-default-layout="true"]), count: 1
      assert_select "html[data-theme='rounded']"
      refute_includes response.body, "min-h-dvh"
    end

    controller = RecordingStudioUser::Auth::SessionsController.new
    assert_equal RecordingStudio::DEFAULT_LAYOUT, controller.send(:recording_studio_resolved_layout)

    confirmations = RecordingStudioUser::Auth::ConfirmationsController.new
    assert_equal RecordingStudio::DEFAULT_LAYOUT, confirmations.send(:recording_studio_resolved_layout)

    passwords = RecordingStudioUser::Auth::PasswordsController.new
    assert_equal RecordingStudio::DEFAULT_LAYOUT, passwords.send(:recording_studio_resolved_layout)
  end

  test "a host Users layout override applies to signed-out auth screens" do
    RecordingStudioUser.configuration.layout = "application"

    get new_user_session_path

    assert_response :success
    assert_select %(body[data-recording-studio-default-layout="true"]), count: 0
    assert_includes response.body, "Welcome back"

    controller = RecordingStudioUser::Auth::SessionsController.new
    assert_equal "application", controller.send(:recording_studio_resolved_layout)

    confirmations = RecordingStudioUser::Auth::ConfirmationsController.new
    assert_equal "application", confirmations.send(:recording_studio_resolved_layout)
  end

  test "nil Users layout falls through to the core layout on signed-out auth" do
    RecordingStudioUser.configuration.layout = nil
    RecordingStudio.configuration.layout = "application"

    get new_user_session_path

    assert_response :success
    assert_select %(body[data-recording-studio-default-layout="true"]), count: 0

    RecordingStudio.configuration.layout = nil

    get new_user_session_path

    assert_response :success
    assert_select %(body[data-recording-studio-default-layout="true"]), count: 1
  end
end
