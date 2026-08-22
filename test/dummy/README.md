# RecordingStudioUser Reference App

This Rails application demonstrates RecordingStudioUser in a host application.

- Host `User` is the Devise actor (email and password only).
- This gem owns the shared **People** root and **Profile** snapshots (`user_id` on Profile).
- One profile image is an Attachable child of the Profile recording. Dummy mounts Attachable and Active Storage.
- Workspace remains the host-owned bucket. Access-controlled, read-only reporting on sitewide users is still mounted.
- Signed-in pages use Recording Studio's default layout (`RecordingStudio::UsesDefaultLayout`). Devise keeps `layouts/application`. Dummy does not own `recording_studio/default_layout`. A `recording_studio/_default_layout_head` hook sets `html data-theme="rounded"` so Flatpack primary tokens resolve on `:root`.
- Profile show/edit are PageNav back/close only. The right slot stays empty. There is no Access control, sidebar Sign out, or Root Switchable on those screens. Show puts Edit in the page title. Edit puts the form in one cell of a two-column Flatpack Grid (the other cell stays empty) so fields do not stretch full-bleed on a wide screen. Each field is still its own full-width row. Update profile and Cancel are separate Flatpack buttons, not a ButtonGroup.
- The photo replace screen uses the same core layout. Dummy overrides Attachable's attachment show so that gem's in-view PageNav is not stacked on top of core's.

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run these commands from the dummy app directory. Sign in through Devise at `/users/sign_in` with one of the seeded accounts:

- `admin@admin.com` / `Password`: first-owner `:admin` on the Admin root, My workspace, and Client Workspace via `bootstrap_owner_access!`. Avery Admin also has a seeded profile photo. Use this account to test workspace switching and the users report.
- `member@admin.com` / `Password`: can sign in but cannot access the Admin root or users report.

## RecordingStudioUser Routes

- `/recording_studio_users/profile`: the signed-in user's profile. Accessible must grant them a role on that Profile recording. Flash notices come from the default layout, not the show template. The photo is the single Attachable child.
- `/recording_studio_users/profile/edit`: profile editing route. Writes go through `record_profile!`. Photo upload and replace use Attachable screens.
- `/recording_studio_attachable/recordings/:recording_id/attachments/upload`: Attachable upload when the profile has no photo.
- `/recording_studio_attachable/attachments/:id`: Attachable revision screen for swapping the photo.
- `/recording_studio_users/admin`: authorizes the actor against the Admin root, then opens the shared read-only users report.

Seeded users get Profile snapshots under People. `record_profile!` bootstraps first-owner `:admin` on each Profile recording with `bootstrap_owner_access!`. People itself is not bootstrapped. User is not a recordable.

## Roots And Access

The dummy app has workspace roots and a separate host-owned Admin root. People is a shared root, not an owned workspace. Accessible and Attachable are enabled on Profile and not on People. Profile screens do not grant other actors.
