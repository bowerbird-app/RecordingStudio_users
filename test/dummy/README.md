# RecordingStudioUser Reference App

This Rails application demonstrates RecordingStudioUser in a host application.

- Host `User` is the Devise actor (email and password only).
- This gem owns the shared **People** root and **Profile** snapshots (`user_id` on Profile).
- Workspace remains the host-owned bucket. Access-controlled, read-only reporting on sitewide users is still mounted.
- Signed-in pages use Recording Studio's default layout (`RecordingStudio::UsesDefaultLayout`). Devise keeps `layouts/application`. Dummy does not own `recording_studio/default_layout`.
- Profile show/edit are PageNav back/close only. Access lives in the PageNav right slot via `recording_access_management_link`. There is no sidebar Sign out or Root Switchable on those screens.

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run these commands from the dummy app directory. Sign in through Devise at `/users/sign_in` with one of the seeded accounts:

- `admin@admin.com` / `Password`: first-owner `:admin` on the Admin root, My workspace, and Client Workspace via `bootstrap_owner_access!`. Use this account to test workspace switching and the users report.
- `member@admin.com` / `Password`: can sign in but cannot access the Admin root or users report.

## RecordingStudioUser Routes

- `/recording_studio_users/profile`: the signed-in user's profile. Accessible must grant them a role on that Profile recording. Flash notices come from the default layout, not the show template.
- `/recording_studio_users/profile/edit`: profile editing route. Writes go through `record_profile!`.
- `/recording_studio_accessible/recordings/:recording_id/accesses`: Accessible's mounted access-management UI. Profile screens link here from the PageNav right slot.
- `/recording_studio_users/admin`: authorizes the actor against the Admin root, then opens the shared read-only users report.

Seeded users get Profile snapshots under People. `record_profile!` bootstraps first-owner `:admin` on each Profile recording with `bootstrap_owner_access!`. People itself is not bootstrapped. User is not a recordable.

## Roots And Access

The dummy app has workspace roots and a separate host-owned Admin root. People is a shared root, not an owned workspace. Accessible is enabled on Profile and on host Workspace / AdminRoot. It is not enabled on People.
