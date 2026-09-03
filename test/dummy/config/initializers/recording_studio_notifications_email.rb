# frozen_string_literal: true

Rails.application.config.to_prepare do
  RecordingStudioNotificationsEmail.configure do |config|
    config.from = "notifications@example.test"
    config.recipients.register(RecordingStudioUser.config.user_class) { |user| user.email }
  end
end
