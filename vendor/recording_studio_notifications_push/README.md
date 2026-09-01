# RecordingStudioNotificationsPush

`recording_studio_notifications_push` is the Firebase Cloud Messaging (FCM)
channel for
[`recording_studio_notifications`](https://github.com/bowerbird-app/RecordingStudio_notifications).
It is a standalone Rails engine under `RecordingStudioNotificationsPush`.

The parent notifications engine owns notification records, preferences,
background delivery, retries, and delivery status. This gem:

- registers a `:push` channel adapter
- stores **device installations** in one ActiveRecord table (not a recordable)
- sends FCM HTTP v1 messages with a service-account OAuth token
- exposes a small Flatpack devices page and a PWA service-worker extension

This channel does **not** implement rollups / `deliver_rollup`.

## Installation

```ruby
gem "recording_studio_notifications"
gem "recording_studio_notifications_push"
# Optional but recommended for installable web apps:
gem "recording_studio_pwa"
```

```bash
bundle install
bin/rails generate recording_studio_notifications:install
bin/rails generate recording_studio_notifications_push:install
bin/rails generate recording_studio_notifications_push:migrations
bin/rails db:migrate
```

Mount the engines:

```ruby
mount RecordingStudioNotifications::Engine, at: "/notifications"
mount RecordingStudioNotificationsPush::Engine, at: "/notifications/push"

# Host PWA chrome (from recording_studio_pwa)
get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
```

During Rails preparation this engine registers:

```ruby
RecordingStudioNotifications.register_channel(
  :push,
  RecordingStudioNotificationsPush.adapter
)
```

When `RecordingStudioPwa` is present it also registers the service-worker
extension partial
`recording_studio_notifications_push/service_worker_push`.

## Configuration

Web client values load from ENV by default:

| ENV | Purpose |
|---|---|
| `FIREBASE_API_KEY` | Firebase web config |
| `FIREBASE_APP_ID` | Firebase web config |
| `FIREBASE_AUTH_DOMAIN` | Firebase web config |
| `FIREBASE_MESSAGING_SENDER_ID` | Firebase web config |
| `FIREBASE_PROJECT_ID` | Web config + FCM v1 project |
| `FIREBASE_STORAGE_BUCKET` | Firebase web config |
| `FIREBASE_VAPID_PUBLIC_KEY` | Web Push certificate key |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Server OAuth for FCM sends |

```ruby
RecordingStudioNotificationsPush.configure do |config|
  config.channel = :push
  # Optional overrides; ENV defaults are usually enough.
  # config.firebase_service_account_json = Rails.application.credentials.dig(:firebase, :service_account_json)
end
```

`FIREBASE_SERVICE_ACCOUNT_JSON` may be unset while developing UI. Delivery
raises `RecordingStudioNotificationsPush::DeliveryError` when a send is
attempted without it.

## Parent notification setup

```ruby
RecordingStudioNotifications.register_notification_type(
  :page_comment,
  label: "Page comment",
  default_channels: %i[in_app push],
  available_channels: %i[in_app email push]
)

RecordingStudioNotifications.notify(
  notification_type: :page_comment,
  recipient: user,
  title: "New comment",
  body: "A collaborator commented on your page.",
  url: page_url(page)
)
```

## Device registration

Authenticated users visit `/notifications/push/devices` to enable the current
browser. The Stimulus controller reads Firebase web config from the page,
requests notification permission, obtains a token via Firebase Messaging
(importmap pins), and POSTs an installation JSON record.

Installations are keyed by polymorphic recipient + `firebase_installation_id`
(FID-first targeting). `legacy_fcm_token` is optional for older clients.

## Development Gemfile pins

Until parent gems are published:

```ruby
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_notifications", github: "bowerbird-app/RecordingStudio_notifications", branch: "main"
gem "recording_studio_pwa", github: "bowerbird-app/RecordingStudio_PWA", branch: "cursor/pwa-service-worker-seam-453c"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.133"
```

## License

MIT
