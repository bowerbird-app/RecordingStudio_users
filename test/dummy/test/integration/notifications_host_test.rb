# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class NotificationsHostTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = password_test_user("notifications-host@example.com")
    sign_in @user
  end

  test "home debug chrome links to notifications inbox settings and push devices" do
    get "/"

    assert_response :success
    assert_select %(a[href="#{recording_studio_notifications.notifications_path}"]), text: "Notifications", count: 1
    assert_select %(a[href="#{recording_studio_notifications.settings_path}"]), text: "Notification settings", count: 1
    assert_select %(a[href="#{recording_studio_notifications_push.devices_path}"]), text: "Push devices", count: 1
    assert_includes response.body, "recording-studio-notifications--notification-polling"
  end

  test "signed-in user can open the notifications inbox" do
    RecordingStudioNotifications.notify(
      notification_type: :generic,
      recipient: @user,
      title: "Inbox check",
      body: "A dummy notice.",
      url: "/",
      channels: [:in_app],
      idempotency_key: "dummy-inbox-check-#{@user.id}"
    )

    get recording_studio_notifications.notifications_path

    assert_response :success
    assert_includes response.body, "Inbox check"
  end

  test "signed-in user can open notification settings" do
    get recording_studio_notifications.settings_path

    assert_response :success
    assert_includes response.body, "Registration code"
    assert_includes response.body, "Login code"
  end

  test "signed-in user can open push devices" do
    get recording_studio_notifications_push.devices_path

    assert_response :success
    assert_includes response.body, "Push Notifications"
    assert_includes response.body, "Firebase is not configured yet"
  end

  private

  def password_test_user(email)
    user = User.find_or_initialize_by(email: email)
    user.password = "Password123!"
    user.password_confirmation = "Password123!"
    user.authentication_method = "password"
    user.skip_confirmation! if user.respond_to?(:skip_confirmation!) && !user.confirmed?
    user.save!
    user
  end
end
