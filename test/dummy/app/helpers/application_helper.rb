module ApplicationHelper
  include RecordingStudioAccessible::AccessManagementHelper
  include RecordingStudioNotifications::MenuHelper

  def notifications_inbox_nav?
    path = request.path
    return false if path.start_with?("/notifications/push")
    return false if path.start_with?(recording_studio_notifications.settings_path)

    path == "/notifications" || path.start_with?("/notifications/")
  end
end
