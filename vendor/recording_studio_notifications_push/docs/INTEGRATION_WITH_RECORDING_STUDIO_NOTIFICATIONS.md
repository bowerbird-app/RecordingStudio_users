# Integration with RecordingStudioNotifications

This gem is a **channel addon**. It does not own notification rows, preferences,
or delivery jobs.

## Responsibilities

| Layer | Owner |
|---|---|
| Notification + delivery records | `recording_studio_notifications` |
| Channel preference + cadence | `recording_studio_notifications` |
| `:push` adapter + FCM HTTP v1 | this gem |
| Device installation rows | this gem (`recording_studio_notifications_push_installations`) |
| Email delivery | `recording_studio_notifications_email` |
| Service worker shell | `recording_studio_pwa` (extension seam) |

## Registration

On `to_prepare`, the engine calls:

```ruby
RecordingStudioNotificationsPush.register!
# => RecordingStudioNotifications.register_channel(:push, adapter)
```

The adapter implements `#deliver(notification:, delivery:)` only. It does **not**
implement `#deliver_rollup`. Types that defer rollups must not list `:push` as a
rollup channel.

## Delivery flow

1. Host calls `RecordingStudioNotifications.notify(...)` with `:push` selected.
2. Parent creates a delivery row and invokes the registered adapter.
3. `FcmAdapter` loads active `Installation` rows for the recipient.
4. Each installation is targeted FID-first (`firebase_installation_id`, then
   `legacy_fcm_token`).
5. `FcmClient` exchanges `FIREBASE_SERVICE_ACCOUNT_JSON` for a Google OAuth
   token and POSTs to FCM HTTP v1.
6. `UNREGISTERED` / `NOT_FOUND` / invalid registration token responses disable
   that installation.
7. Delivery succeeds when **at least one** installation send succeeds.
8. If no installations exist, or every send fails, the adapter raises
   `DeliveryError`.

Web payloads are **data-only** (title, body, and url in `data`). The PWA
service-worker extension always calls `registration.showNotification` for
the native Chrome OS banner — not an in-page HTML alert.

## Diagnosing a missing notification

An FCM `200` only means FCM accepted the message. The devices page exposes two
checks that separate the failure modes:

| Check | Path exercised | What a silent result means |
|---|---|---|
| Show a local notification | service worker only, no FCM | browser or OS is hiding notifications |
| Send a test push | `POST /installations/:id/test_push` → FCM → service worker | FCM reports its own verdict inline |

`RecordingStudioNotificationsPush::TestPush` powers the second check and returns
`accepted`, `status`, and `error`.

## PWA seam

When `RecordingStudioPwa` is loaded, this engine registers:

```ruby
RecordingStudioPwa.register_service_worker_extension(
  "recording_studio_notifications_push/service_worker_push"
)
```

The partial adds `push` and `notificationclick` handlers that call
`showNotification` from the payload (with `/icon.png` by default).

Pass a custom thumbnail with notification metadata:

```ruby
RecordingStudioNotifications.notify(
  ...,
  metadata: { icon: "/push-icon-coral.png" }
)
```

The FCM adapter copies `metadata[:icon]` into the data-only payload as `icon`.
## Mount points

Suggested host routes:

```ruby
mount RecordingStudioNotifications::Engine, at: "/notifications"
mount RecordingStudioNotificationsPush::Engine, at: "/notifications/push"
```

Devices UI: `/notifications/push/devices`  
Installations JSON: `POST/DELETE /notifications/push/installations`
