# frozen_string_literal: true

RecordingStudioNotificationsPush.configure do |config|
  # Channel key registered with RecordingStudioNotifications (default :push).
  # config.channel = :push

  # Web client config is loaded from ENV by default:
  # FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_AUTH_DOMAIN,
  # FIREBASE_MESSAGING_SENDER_ID, FIREBASE_PROJECT_ID, FIREBASE_STORAGE_BUCKET,
  # FIREBASE_VAPID_PUBLIC_KEY
  #
  # Server sends require FIREBASE_SERVICE_ACCOUNT_JSON (full service-account JSON).
  # Delivery raises DeliveryError when it is missing at send time.

  # config.firebase_project_id = ENV.fetch("FIREBASE_PROJECT_ID", nil)
  # config.vapid_public_key = ENV.fetch("FIREBASE_VAPID_PUBLIC_KEY", nil)
  # config.firebase_service_account_json = ENV.fetch("FIREBASE_SERVICE_ACCOUNT_JSON", nil)
end
