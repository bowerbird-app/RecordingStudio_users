# Changelog

## Unreleased

## 0.2.0

### Added
- `FcmAdapter#available_for?` returns false when the recipient has no active push
  installations.

### Changed
- Push `Event` resolves title, body, and url via
  `RecordingStudioNotifications.delivery_payload_for` when a delivery is present.
- Require `recording_studio_notifications` `>= 0.3.0`.

### Upgrade notes
- Install `recording_studio_notifications` `0.3.0` (or later) before bumping to
  `0.2.0`.

## 0.1.15

### Changed
- `FcmAdapter` builds one FCM payload per notification before fanning out to
  installations instead of recomputing title, body, url, and metadata assets
  for every device
- `Event#metadata` is memoized so icon and image resolution reuse one frozen
  copy
- Firebase web-client readiness now lives on
  `RecordingStudioNotificationsPush.configuration.web_push_client_ready?`
- Devices page secondary actions (Manage notifications, Not getting alerts?)
  render from one shared template block
- Removed unused `testPushUrlTemplate` Stimulus value from the push devices
  controller

## 0.1.14

### Changed
- Help modal title is now **Not receiving push notifications?**
- Removed browser/OS detection line, permission status line, and system-toggle
  disclaimer from the help modal — only the step lists remain

## 0.1.13

### Fixed
- Notification help modal is filled on page load (before it is opened), with
  generic fallback steps in HTML when JavaScript has not run yet
- Push devices Stimulus controller is preloaded so browser and OS detection
  finishes before users tap **Not getting alerts?**

## 0.1.12

### Changed
- Notification help now follows the same three-step format for every detected
  browser and OS, using vendor-documented settings paths
- iPhone and iPad guidance now correctly requires an iOS/iPadOS 16.4+ Home
  Screen web app and points to that web app—not the browser—in Notifications
- iPhone and iPad setup in Firefox or Opera directs users to a supported
  installation browser instead of implying in-tab website push support
- Safari on Mac now points to the website entry under Application Notifications

## 0.1.11

### Changed
- Mac Chrome help modal steps now point to `chrome://settings/`, Privacy and
  security → Site settings → Notifications, and “Sites can ask to send
  notifications”

## 0.1.10

### Added
- Devices page **Not getting alerts?** opens a help modal with steps tailored to
  the detected browser and OS (site permission + system notification settings)

## 0.1.9

### Changed
- Devices page puts **Enable** and **Manage notifications** side by side; when
  this browser is already registered, only **Manage notifications** remains

### Fixed
- RuboCop cyclomatic complexity on Event `#meta_asset`

## 0.1.8

### Fixed
- Service worker resolves notification `icon` / `image` to absolute URLs before
  `showNotification` (relative paths were easy to miss on forwarded origins)
- Push `metadata[:icon]` / `[:image]` accept absolute http(s) URLs without the
  notification URL host allowlist (banner assets are not navigation targets)

### Changed
- Dummy icon test sends store absolute icon+image URLs and preview the thumbnail
  in the home inbox / test results
- Dummy copy notes that macOS Chrome keeps the Chrome app badge on the left

## 0.1.7

### Added
- Push payloads include `data.icon` from notification `metadata[:icon]` so the
  service worker can show a custom OS banner thumbnail (falls back to `/icon.png`)
- Dummy home has **Test coral icon** and **Test teal icon** buttons that send
  push demos with `/push-icon-coral.png` and `/push-icon-teal.png`

## 0.1.6

### Added
- Devices page **Manage notifications** default button under the subtitle links to
  the parent notifications settings screen

### Fixed
- Devices trash button uses `data-turbo-method="delete"` so remove redirects back
  to `/notifications/push/devices` instead of a GET routing error

## 0.1.5

### Changed
- Push devices page title is **Push Notifications** with subtitle **Get notifications on your devices**
- Enable button reads **Enable on this device** in an installed PWA and **Enable on this browser** in a normal tab
- Device list uses FlatPack `List` with mobile (`device_phone_mobile`) or desktop (`computer_desktop`) leading icons
- Remove uses a FlatPack ghost icon button (`trash`) instead of a text link
- Empty-state copy and inline enable status text removed
- When push is already enabled on this browser/device, the enable button is hidden (use **Remove** on the list row to turn off)

## 0.1.4

### Fixed
- FCM web sends are **data-only** again; the service worker always calls `showNotification`. Skipping display when FCM included a `notification` block left Chrome with no banner because an active service worker must show it itself.

## 0.1.3

### Fixed
- Restore FCM `notification` payloads for web push display; data-only sends stopped showing alerts in Chrome
- Service worker only skips `showNotification` when the push payload includes a real notification title/body (avoids swallowing data-only messages that still carry an empty `notification` object)

## 0.1.2

### Fixed
- FCM web sends no longer include a `notification` block alongside `data`, which duplicated OS banners when the service worker was active

## 0.1.1

### Changed
- Data-only FCM web payloads so the service worker shows a **native Chrome** notification via `showNotification`
- Disable installations on invalid FCM registration tokens
- Service worker notification options include `/icon.png` for a standard Chrome banner look

## 0.1.0

First product release of the Recording Studio Firebase push channel.

- Register `:push` with `RecordingStudioNotifications`
- Store installations in `recording_studio_notifications_push_installations`
- FCM HTTP v1 client with hand-rolled service-account OAuth (no googleauth)
- Flatpack devices page + Stimulus registration controller
- PWA service-worker extension partial for background `showNotification`
- Install + migrations generators
- No rollups / no `deliver_rollup`
