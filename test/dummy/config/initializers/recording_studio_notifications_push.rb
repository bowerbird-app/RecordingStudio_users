# frozen_string_literal: true

if Rails.env.test?
  Rails.application.config.to_prepare do
    RecordingStudioNotificationsPush.configure do |config|
      config.firebase_project_id ||= "test-project"
      config.firebase_service_account_json ||= '{"type":"service_account","project_id":"test-project"}'
    end
  end
end
