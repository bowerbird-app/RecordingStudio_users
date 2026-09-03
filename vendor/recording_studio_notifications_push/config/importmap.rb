# frozen_string_literal: true

pin "controllers/recording_studio_notifications_push/push_devices_controller",
    preload: true

pin_all_from RecordingStudioNotificationsPush::Engine.root.join("app/javascript/recording_studio_notifications_push/controllers"),
             under: "controllers/recording_studio_notifications_push",
             to: "recording_studio_notifications_push/controllers",
             preload: false

# Firebase modular ESM builds. Hosts may override these pins.
pin "firebase/app", to: "https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js", preload: false
pin "firebase/messaging", to: "https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging.js", preload: false
