# RecordingStudioUser Reference App

This Rails application demonstrates RecordingStudioUser in a host application.

- Host `User` is the Devise actor (email and password only).
- This gem owns the shared **People** root and **Profile** snapshots (`user_id` on Profile).
- One profile image is an Attachable child of the Profile recording. Dummy mounts Attachable and Active Storage.
- Workspace remains the host-owned bucket. Access-controlled, read-only reporting on sitewide users is still mounted.
- Signed-in pages use Recording Studio's default layout (`RecordingStudio::UsesDefaultLayout`). Devise keeps `layouts/application` with `html data-theme="rounded"`. Dummy does not own `recording_studio/default_layout`. A `recording_studio/_default_layout_head` hook sets the same theme on signed-in pages so Flatpack primary tokens resolve on `:root`. Login and sign up are Devise views that use Flatpack inputs and a primary button. They are not a Users product registration flow.
- Profile show/edit are PageNav back/close only. The right slot stays empty. There is no Access control, sidebar Sign out, or Root Switchable on those screens. Show puts Edit in the page title and one elevated identity Card. A two-column Grid wraps the Card only (desktop width cap). Inside the card, Avatar sits above unlabeled name, email, and time zone in one column. Empty photos show Avatar's person icon. Edit calls Attachable `render_parent_attachment(..., shape: :circle, size: :"2xl")` for Avatar plus Add/Change. Dummy pins Flatpack `v0.1.135` so that size is `h-24 w-24`. An `mb-8` wrapper under the helper separates the photo row from First name. Edit puts the form in one cell of a two-column Flatpack Grid (the other cell stays empty) so fields do not stretch full-bleed on a wide screen. Each field is still its own full-width row. Update profile and Cancel are separate Flatpack buttons, not a ButtonGroup.
- Dummy still overrides Attachable's leftover attachment show so that gem's in-view PageNav is not stacked on top of core's. Profile screens do not link there.

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run these commands from the dummy app directory. Sign in through Devise at `/users/sign_in` with one of the seeded accounts, or create one at `/users/sign_up`:

- `admin@admin.com` / `Password`: first-owner `:admin` on the Admin root, My workspace, and Client Workspace via `bootstrap_owner_access!`. Avery Admin also has a seeded profile photo. Use this account to test workspace switching and the users report.
- `member@admin.com` / `Password`: can sign in but cannot access the Admin root or users report.

## RecordingStudioUser Routes

- `/recording_studio_users/profile`: the signed-in user's profile. Accessible must grant them a role on that Profile recording. Flash notices come from the default layout, not the show template. The photo is the single Attachable child. Show is an elevated identity Card plus Edit in the title. `doc/review/profile-show.png` is desktop; `doc/review/profile-show-mobile.png` is ~390px.
- `/recording_studio_users/profile/edit`: profile editing route. Writes go through `record_profile!`. The photo row is Attachable `render_parent_attachment` at `size: :"2xl"` (Add/Change posts stay on this page). Dummy pins Attachable `cursor/file-only-replace-path-a5db` at `1477cc9242f2cddb8ca5b955e9ca9833a8ab6b0a` and Flatpack `v0.1.135`. `doc/review/profile-edit.png` is Avery plus Change; `doc/review/profile-edit-empty.png` is the grey Avatar plus Add.
- `/recording_studio_attachable/attachments/:id`: leftover Attachable record screen if opened directly. Profile does not link here.
- `/recording_studio_users/admin`: authorizes the actor against the Admin root, then opens the shared read-only users report.

Seeded users get Profile snapshots under People. `record_profile!` bootstraps first-owner `:admin` on each Profile recording with `bootstrap_owner_access!`. People itself is not bootstrapped. User is not a recordable.

## Roots And Access

The dummy app has workspace roots and a separate host-owned Admin root. People is a shared root, not an owned workspace. Accessible and Attachable are enabled on Profile and not on People. Profile screens do not grant other actors.
