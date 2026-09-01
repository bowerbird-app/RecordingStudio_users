# Migration notes

## 0.2.0

### Host app steps

1. Bump `recording_studio_notifications` to `0.3.0` (or later) first.
2. Bump `recording_studio_notifications_push` to `0.2.0`. No configuration or
   migration changes are required.

## 0.1.15

### Host app steps

1. Bump to `0.1.15`. No configuration or migration changes are required.

## 0.1.14

### Host app steps

1. Bump to `0.1.14` and hard-refresh the push devices page.

## 0.1.13

### Host app steps

1. Bump to `0.1.13` and hard-refresh the push devices page so the preloaded
   help modal JavaScript loads.
2. No configuration changes are required.

## 0.1.12

### Host app steps

1. Bump to `0.1.12` and refresh the devices page for the fact-checked browser
   and OS help.
2. On iPhone and iPad, make sure the PWA manifest has a clear app name. Users
   find that Home Screen web app name—not Safari or Chrome—in Settings →
   Notifications.

## 0.1.11

### Host app steps

1. Bump to `0.1.11` and refresh the devices page so the updated Mac Chrome
   help steps load.

## 0.1.10

### Host app steps

1. Bump to `0.1.10` and refresh the devices page so the help modal and client
   detection script load.

## 0.1.9

### Host app steps

1. Bump to `0.1.9` and refresh the devices page.
2. Enable and Manage notifications now share one row. After this browser is
   enabled, only Manage notifications stays visible.

## 0.1.8

### Host app steps

1. Bump to `0.1.8` and hard-refresh / re-register the service worker so it picks
   up absolute icon URL resolution.
2. Prefer absolute `https://…` icon URLs in `metadata[:icon]` when the host is
   not same-origin with the worker (path-only values still work and are
   absolutized in the worker).
3. **macOS Chrome:** the left OS badge is the Chrome app icon. Custom
   `icon` / `image` values show on Windows and Android; macOS may only show a
   small secondary thumbnail, or none.

## 0.1.7

### Host app steps

1. Bump to `0.1.7`.
2. To customize the OS banner thumbnail per notification, pass
   `metadata: { icon: "/your-icon.png" }` (or an https URL) into
   `RecordingStudioNotifications.notify`. The service worker still falls back
   to `/icon.png` when `icon` is omitted.

## 0.1.6

### Host app steps

1. Bump to `0.1.6` and refresh the devices page.
2. Removing a device uses Turbo `DELETE` and returns you to the devices list.
3. **Manage notifications** on the devices page opens the parent gem settings at
   `/notifications/settings` (or wherever that engine is mounted).

## 0.1.1

### Host app steps

1. Bump to `0.1.1` and restart so Propshaft digests pick up the refreshed
   service-worker extension.
2. Hard-refresh browsers (or unregister the old service worker) so they load the
   SW that calls `registration.showNotification` for native Chrome banners.
3. Native display is owned by the PWA service-worker extension
   (`showNotification`), not an in-page HTML toast.
4. Enable push on **each** browser under `/notifications/push/devices` — FCM
   only reaches registered installations for that account.
5. New route `POST /installations/:id/test_push` backs the devices-page
   diagnostics. It is scoped to the current actor's own active installations.

## 0.1.0 (from gem template)

This repository was renamed from the Recording Studio gem template to
`recording_studio_notifications_push`. Template sample tables and capabilities
are gone.

### Host app steps

1. Add the gem and parent notifications gem.
2. Run `bin/rails generate recording_studio_notifications_push:install`.
3. Run `bin/rails generate recording_studio_notifications_push:migrations`.
4. Set Firebase ENV vars (see README). Service account JSON is required to
   **send**; UI registration can run without it.
5. Mount the engine (suggested `/notifications/push`).
6. Enable `:push` on notification types in the parent notifications initializer.
7. If using `recording_studio_pwa`, mount manifest + service-worker routes so
   the push SW extension can load.

### Breaking vs template

- Removes `recording_studio_notifications_push_pages` sample migration.
- Removes example capability hooks and template home controller.
- Version is `0.1.0` for the product gem (not a continuation of template `0.2.0`).

### Bundler note: notifications_email + Recording Studio 4.2

Upstream `recording_studio_notifications_email` on `main` still gemspecs
`recording_studio >= 3, < 4`, which conflicts with this gem's `~> 4.2` stack and
`recording_studio_pwa`.

This repo vendors a temporary compatibility checkout at
`vendor/recording_studio_notifications_email` with:

- `recording_studio ~> 4.2`
- `recording_studio_notifications >= 0.2, < 1`

Root and dummy Gemfiles point at that path by default. Override with
`RECORDING_STUDIO_NOTIFICATIONS_EMAIL_PATH` when testing against another
checkout. Remove the vendored copy once upstream publishes a 4.x-compatible
gemspec.
