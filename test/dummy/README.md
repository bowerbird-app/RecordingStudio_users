# RecordingStudioUser Reference App

This Rails application demonstrates RecordingStudioUser in a host application.

- Host `User` is the Devise actor (email and password only).
- This gem owns the shared **People** root and **Profile** snapshots (`user_id` on Profile).
- One profile image is an Attachable child of the Profile recording. Dummy mounts Attachable and Active Storage.
- Workspace remains the host-owned bucket. Access-controlled, read-only reporting on sitewide users is still mounted.
- Login and sign up are Devise views. They viewport-center with ordinary Tailwind (`min-h-dvh`, inner `max-w-sm`), no Card, no Remember me, no seed Badge. Login title is `login_title` (default Welcome back). Sign-up confirmation is off unless `require_password_confirmation` is true. Continue-with sits under a Flatpack Divider labeled Or. Dummy development credentials keep Google live. They are not a Users product registration flow. Recapture: `doc/review/users_sign_in.png`, `doc/review/users_sign_up.png`.
- Product surfaces (Profile, Attachable leftovers, Root Switchable) use Recording Studio's default layout (`RecordingStudio::UsesDefaultLayout`). Devise keeps `layouts/application` with `html data-theme="rounded"`. Dummy does not own `recording_studio/default_layout`. A `recording_studio/_default_layout_head` hook sets the same theme on those pages so Flatpack primary tokens resolve on `:root`.
- Home (`/`) and the `/docs/*` debug pages use `layouts/flat_pack_sidebar`: left sidebar with Install, Config, Routes and integrations, diagnostics, My profile, and Sign out, plus a top nav with the Root Switchable dropdown. That chrome is for host debugging, not the Profile product UI.
- Profile show/edit are PageNav back/close only. The right slot stays empty. There is no Access control, sidebar Sign out, or Root Switchable on those screens. Show puts Edit in the page title and one elevated identity Card. A two-column Grid wraps the Card only (desktop width cap). Inside the card, Avatar sits above unlabeled name, email, and time zone in one column. Empty photos show Avatar's person icon. Edit hosts a `profile-photo` Turbo frame with Flatpack Avatar (`attachment_preview_url`, `size: :"2xl"`) plus Attachable `render_attachment_file_button` for Add/Change. Dummy pins Flatpack `v0.1.143`. An `mb-8` wrapper around the frame separates the photo row from First name. Edit puts the form in one cell of a two-column Flatpack Grid (the other cell stays empty) so fields do not stretch full-bleed on a wide screen. Each field is still its own full-width row. Update profile and Cancel are separate Flatpack buttons, not a ButtonGroup.
- Dummy still overrides Attachable's leftover attachment show so that gem's in-view PageNav is not stacked on top of core's. Profile screens do not link there.
- Dummy OmniAuth reads filled `omniauth:` keys from Rails credentials. Encrypted development credentials live in `config/credentials/development.yml.enc` (Google is live; Microsoft, Apple, LinkedIn, and Instagram are commented examples). Encrypted test credentials live in `config/credentials/test.yml.enc` so the dummy suite can cover every provider. `development.key` and `test.key` are committed for this reference app. The dummy app never sets `OmniAuth.config.test_mode` or `OMNIAUTH_TEST_MODE`.

## Google OAuth in development

The dummy app's live Google client lives in the **BowerBird Dev** GCP project, as the **RecordingStudioUsers** Web application client:

- [OAuth clients in BowerBird Dev](https://console.cloud.google.com/auth/clients?project=key-buttress-507301-d2)
- [RecordingStudioUsers client](https://console.cloud.google.com/auth/clients/332241240783-36h23frfv5ovlnqtkcc3cc1a96afqkji.apps.googleusercontent.com?project=key-buttress-507301-d2)

Authorized redirect URI on that client:

```text
http://localhost:3000/users/auth/google_oauth2/callback
```

Also register `http://127.0.0.1:3000/users/auth/google_oauth2/callback` if you open the dummy as `127.0.0.1`. Google treats `localhost` and `127.0.0.1` as different URIs. After saving the client, wait a few minutes before retrying.

Encrypted dummy credentials already hold this client's id and secret. To point a fork at a different client, or to add Microsoft, Apple, LinkedIn, or Instagram:

```bash
cd test/dummy
EDITOR="nano" bin/rails credentials:edit --environment development
```

Uncomment and fill a provider to show its Continue-with button:

```yaml
omniauth:
  google_oauth2:
    client_id: your-google-client-id
    client_secret: your-google-client-secret
  # microsoft_graph:
  #   client_id: your-microsoft-client-id
  #   client_secret: your-microsoft-client-secret
  # apple:
  #   client_id: your-apple-client-id
  #   client_secret: ""
  #   team_id: your-apple-team-id
  #   key_id: your-apple-key-id
  #   pem: |
  #     -----BEGIN PRIVATE KEY-----
  #     ...
  #     -----END PRIVATE KEY-----
  # linkedin:
  #   client_id: your-linkedin-client-id
  #   client_secret: your-linkedin-client-secret
  # instagram:
  #   client_id: your-instagram-client-id
  #   client_secret: your-instagram-client-secret
```

Start the dummy. Continue with Google talks to Google when those credential keys are set.

```bash
cd test/dummy
bin/rails server -b 0.0.0.0 -p 3000
```

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
- `/recording_studio_users/profile/edit`: profile editing route. Writes go through `record_profile!`. The photo row is a host `profile-photo` Turbo frame: Avatar via `attachment_preview_url(..., variant: :square_med)` plus Attachable `render_attachment_file_button` (Add/Change posts stay on this page). Dummy pins Attachable tag `v0.5.0` and Flatpack `v0.1.143`. `doc/review/profile-edit.png` is Avery plus Change; `doc/review/profile-edit-empty.png` is the grey Avatar plus Add.
- `/recording_studio_attachable/attachments/:id`: leftover Attachable record screen if opened directly. Profile does not link here.
- `/recording_studio_users/admin`: authorizes the actor against the Admin root, then opens the shared read-only users report.

Seeded users get Profile snapshots under People. `record_profile!` bootstraps first-owner `:admin` on each Profile recording with `bootstrap_owner_access!`. People itself is not bootstrapped. User is not a recordable.

## Roots And Access

The dummy app has workspace roots and a separate host-owned Admin root. People is a shared root, not an owned workspace. Accessible and Attachable are enabled on Profile and not on People. Profile screens do not grant other actors.
