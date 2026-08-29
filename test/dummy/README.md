# RecordingStudioUser Reference App

This Rails application demonstrates RecordingStudioUser in a host application.

- Host `User` is the Devise actor (email and password only).
- This gem owns the shared **People** root and **Profile** snapshots (`user_id` on Profile).
- One profile image is an Attachable child of the Profile recording. Dummy mounts Attachable and Active Storage.
- Workspace remains the host-owned bucket. Access-controlled, read-only reporting on sitewide users is still mounted.
- Signed-in pages use Recording Studio's default layout (`RecordingStudio::UsesDefaultLayout`). Devise keeps `layouts/application` with `html data-theme="rounded"`. Dummy does not own `recording_studio/default_layout`. A `recording_studio/_default_layout_head` hook sets the same theme on signed-in pages so Flatpack primary tokens resolve on `:root`. Login and sign up share the Flatpack auth stack with Grid `cols: 2` width cap (no Card): `login_title` (default Welcome back) / Sign up → fields → primary button → cross-link → Divider `Or` → full-width Continue-with buttons (provider logos via `icon:`). No Remember me on login. Login seed hint sits under the form. OmniAuth test mode mocks Google, Microsoft, Apple, LinkedIn, and Instagram. They are not a Users product registration flow.
- Profile show/edit are PageNav chrome only. The right slot stays empty. There is no Access control, sidebar Sign out, or Root Switchable on those screens. Show puts Edit and Sign-in methods in the page title and one elevated identity Card (no `page_nav_back_*`; Flatpack PageNav may still paint history.back). A two-column Grid wraps the Card only (desktop width cap). Inside the card, Avatar sits above unlabeled name, email, and time zone in one column. Empty photos use profile-name initials (never the word “Avatar”). Edit hosts a `profile-photo` Turbo frame with Flatpack Avatar (`attachment_preview_url`, `size: :"2xl"`, name/alt from the profile) plus Attachable `render_attachment_file_button` for Add/Change — photo + name + timezone + Update/Cancel only. Connect / Disconnect live on `/recording_studio_users/profile/sign-in-methods` as matching Card + List rows with the configured provider logos. Dummy pins Flatpack `v0.1.142` (Divider + `:"2xl"` Avatar). An `mb-8` wrapper around the frame separates the photo row from First name. Edit puts the form in one cell of a two-column Flatpack Grid (the other cell stays empty) so fields do not stretch full-bleed on a wide screen. Each field is still its own full-width row. Update profile and Cancel are separate Flatpack buttons, not a ButtonGroup. Edit subtitle is the profile name (not `large_subtitle`).
- Review screenshots for Google OAuth live under `docs/review/google-oauth/`.
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

- `/recording_studio_users/profile`: the signed-in user's profile. Accessible must grant them a role on that Profile recording. Flash notices come from the default layout, not the show template. The photo is the single Attachable child. Show is an elevated identity Card plus **Edit** and **Sign-in methods** in the title (no Connect/Disconnect on show). Review stills for OAuth live under `docs/review/google-oauth/`.
- `/recording_studio_users/profile/edit`: profile editing route. Writes go through `record_profile!`. The photo row is a host `profile-photo` Turbo frame: Avatar via `attachment_preview_url(..., variant: :square_med)` plus Attachable `render_attachment_file_button` (Add/Change posts stay on this page). Dummy pins Attachable tag `v0.5.0` and Flatpack `v0.1.142`. Empty photos use profile-name initials (never the word “Avatar”).
- `/recording_studio_users/profile/sign-in-methods`: owner-only Sign-in methods (same Accessible grant as Edit). Flatpack elevated Card + List: linked providers show logo, name, email, Disconnect; when Google is configured but not linked, the same row shows logo, Google, and Connect (secondary, sm). Core PageNav back to My Profile.
- `/recording_studio_attachable/attachments/:id`: leftover Attachable record screen if opened directly. Profile does not link here.
- `/recording_studio_users/admin`: authorizes the actor against the Admin root, then opens the shared read-only users report.

Profile photo previews use Active Storage variants (`square_med`). The dummy expects `libvips` (Rails default `:vips` processor) so `attachment_preview_url` can render Avery’s seeded image in development and screenshots.

Seeded users get Profile snapshots under People. `record_profile!` bootstraps first-owner `:admin` on each Profile recording with `bootstrap_owner_access!`. People itself is not bootstrapped. User is not a recordable.

## Roots And Access

The dummy app has workspace roots and a separate host-owned Admin root. People is a shared root, not an owned workspace. Accessible and Attachable are enabled on Profile and not on People. Profile screens do not grant other actors.
