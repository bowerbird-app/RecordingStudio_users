# RecordingStudioUser

`RecordingStudioUser` is an isolated, mountable Rails engine. It keeps the host `User` as a Devise actor and owns **People** plus **Profile** as Recording Studio recordables.

- **User** stays the actor only: Devise, uuid, email, password. It is not a recordable and not a root.
- **People** is this gem's shared root (`label: "People"`, `root: true`, `shared: true`), the same idea as core's `MessagesRoot`. Workspace remains the host's owned bucket.
- **Profile** is the only child under People. One current profile per user, with `user_id` on the snapshot. User is not in the tree.
- One profile image sits under the Profile recording as an Attachable child. Not a gallery. Not a parallel table.

Accessible grants live on **Profile** recordings so the owner can show and edit. Profile screens do not invite other actors. This gem still ships the mounted profile routes and the read-only RecordingStudioAdmin users report.

## Installation

Add the engine to the host application's Gemfile:

```ruby
gem "recording_studio_user"
```

`recording_studio` (~> 4.2), `recording_studio_accessible` (~> 0.7), `recording_studio_attachable` (~> 0.5.0), `recording_studio_admin`, `flat_pack` (~> 0.1.141), `devise`, and the supported OmniAuth strategies are runtime dependencies. This gem enables Accessible and Attachable on Profile only. It does not enable either on People.

The host remains responsible for its existing User and Devise setup, Active Storage, and the Attachable mount.

Then run:

```bash
bin/rails generate recording_studio_user:install
bin/rails generate recording_studio_user:migrations
bin/rails generate recording_studio_attachable:install
bin/rails generate recording_studio_attachable:migrations
bin/rails db:migrate
```

Register the gem's recordables next to the host's types, including Attachable's attachment type:

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "RecordingStudioUser::People",
    "RecordingStudioUser::Profile",
    "RecordingStudioAttachable::Attachment"
  ]
end
```

Rerunning the installer is idempotent while the generated mount declaration remains intact. It mounts the engine with the `recording_studio_users` alias and creates `config/initializers/recording_studio_user.rb` only when that file does not already exist. The migrations generator copies the People and Profile tables. The installer does not generate a user model, users table, or Devise routes.

Route configuration values for `mount_path`, `profile_route_path`, and `admin_route_path` must be available **before the host evaluates the engine mount and Rails draws routes**:

```ruby
RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.mount_path = "/account"
  config.profile_route_path = "me"
  config.admin_route_path = "user-reporting"
  config.layout = "application"
  config.additional_profile_attributes = []
  config.require_password_confirmation = true
end
```

Host code uses the mounted-engine proxy:

```ruby
recording_studio_users.profile_path
recording_studio_users.edit_profile_path
recording_studio_users.admin_path
```

## Social sign-in

The dummy app's Google client is **RecordingStudioUsers** in the [BowerBird Dev](https://console.cloud.google.com/auth/clients?project=key-buttress-507301-d2) GCP project ([client](https://console.cloud.google.com/auth/clients/332241240783-36h23frfv5ovlnqtkcc3cc1a96afqkji.apps.googleusercontent.com?project=key-buttress-507301-d2)). Redirect URI: `http://localhost:3000/users/auth/google_oauth2/callback`. See `test/dummy/README.md`.

Continue-with buttons appear only for providers whose secrets are present in Rails credentials under `omniauth:`. An empty `omniauth_providers` hash (the default) reads those credentials. Commented-out or blank credential keys stay hidden. Do not use environment-variable fallbacks or OmniAuth test mode in the app.

Add keys with `bin/rails credentials:edit` (or `--environment development`):

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

`config.omniauth_create_account` still controls whether an unknown provider email creates a User. An explicit non-empty `omniauth_providers` hash still overrides credentials. Apple also accepts `team_id`, `key_id`, `pem`, and `scope`. Point host Devise callbacks at the engine controller:

```ruby
devise_for :users, controllers: {
  omniauth_callbacks: "recording_studio_user/omniauth_callbacks"
}
```

Render `recording_studio_user/omniauth/continue_with_providers` in the host's Devise login and sign-up views. The engine adds `:omniauthable` only when providers are configured. Run `bin/rails generate recording_studio_user:migrations` and `bin/rails db:migrate` to restore the identities table; the 0.6.2 migration is safe whether a host retained or dropped the 0.6.0 table.

On callback, Users first finds `provider` + `uid`. For a new identity, it normalizes the provider email and automatically links it to the existing User with that email. An email explicitly marked unverified by the provider is rejected. If the User supports Devise Confirmable, an unconfirmed existing email is also rejected. Hosts without Confirmable must otherwise verify email ownership during password registration before enabling automatic social-account linking. If no User matches, `omniauth_create_account` controls whether `Directory.create_user!` creates the User and Profile. Setting it to `false` fails closed for unknown emails. OAuth tokens are not stored.

**Sign-in methods** lists only providers that are still configured. An identity for a provider whose credentials were removed is inert — no strategy or callback route exists for it — so it is hidden and does not count as a remaining sign-in method when disconnecting. Delete those rows with:

```bash
bin/rails recording_studio_user:prune_unconfigured_identities
```

First login requires an email. Instagram often returns none, and Apple may return an email only on first consent or use a private relay; those first logins fail closed when no email is available. A signed-in user can still connect such a provider from **My Profile → Sign-in methods**, because the provider identity can safely attach to the current User without inventing an email. Disconnect is blocked when it would remove the only sign-in method from a user without a password.

## User contract

The configured `user_class_name` must name the existing, Devise-compatible Active Record class returned by `current_user`. It must use the host's UUID primary key and provide `email`, password digest, and timestamps. It must **not** store `first_name`, `last_name`, `time_zone`, or `additional_profile_attributes` — those belong on Profile.

## People and Profile

People is a shared root. Nobody owns the forest through that root node. Accessible and Attachable are enabled on Profile, the domain child, not on People.

```ruby
class RecordingStudioUser::People < ApplicationRecord
  recording_studio_recordable label: "People", root: true, shared: true
end

class RecordingStudioUser::Profile < ApplicationRecord
  ALLOWED_PARENT_TYPES = ["RecordingStudioUser::People"].freeze

  recording_studio_recordable label: "Profile",
                              root: false,
                              allowed_parent_types: ALLOWED_PARENT_TYPES
  RecordingStudio.enable_capability(:accessible, on: self)
  include RecordingStudio::Capabilities::Attachable.to(
    allowed_content_types: ["image/*"],
    enabled_attachment_kinds: %i[image],
    max_file_count: 1
  )
end
```

`max_file_count` is the Attachable per-upload batch limit, not a lifetime cap. The product still shows one image: upload when empty, replace when present.

Profile snapshots hold `first_name`, `last_name`, `time_zone`, and `additional_profile_attributes`. Writes go through public helpers, never raw `Recording` / `Event` inserts:

```ruby
user = RecordingStudioUser.create_user!(
  email: "ada@example.com",
  password: "Password123!",
  first_name: "Ada",
  last_name: "Lovelace",
  time_zone: "UTC"
)

RecordingStudioUser.display_name_for(user) # => "Ada Lovelace"
RecordingStudioUser.profile_for(user)

RecordingStudioUser.record_profile!(
  user,
  first_name: "Ada",
  last_name: "Byron",
  time_zone: "UTC"
)

RecordingStudioUser.attach_profile_image!(
  user,
  io: File.open("ada.png"),
  filename: "ada.png",
  content_type: "image/png"
)
RecordingStudioUser.profile_image_recording_for(user)
```

`create_user!` creates the Devise user, then `people_root.record(Profile)`, then `RecordingStudioAccessible.bootstrap_owner_access!` on that Profile recording (role `:admin`). Do not bootstrap People — Accessible rejects the shared root on purpose. Later membership uses `grant_access`. Later profile changes `revise` the existing recording so a new snapshot row is created. `display_name_for` reads the current Profile, then a custom `full_name` / `name`, then email.

`attach_profile_image!` calls Attachable's `ImportAttachment` on the Profile recording. A second call returns the existing image. `replace_profile_image!` swaps the file on that same attachment through `replace_attachment_file`. Edit Profile hosts a `profile-photo` Turbo frame: Flatpack Avatar via `attachment_preview_url` (circle, 2xl) plus Attachable `render_attachment_file_button` so Add/Change stays on that page. My Profile shows the Avatar only. Neither screen opens Attachable's Name / Description record edit.

`additional_profile_attributes` on configuration is an allowlist of extra keys stored in the Profile jsonb column. Identity, credential, authorization, membership, root, recording, and recordable fields stay protected.

`require_password_confirmation` defaults to `true`. Host Devise sign-up should hide the confirmation field and skip the param when this is `false`. The included `ProfiledUser` concern copies `password` into `password_confirmation` so Devise Validatable does not fail.

## Email OTP authentication (opt-in)

OTP registration and login are **disabled by default**. Turn them on only after running the OTP migrations and installing `recording_studio_notifications` with the email channel gem (and push, if you want login codes on devices).

```ruby
RecordingStudioUser.configure do |config|
  config.otp_enabled = true
  config.otp_registration_enabled = true
  config.otp_login_enabled = true
  config.registration_authentication_methods = %i[password otp]
  config.otp_registration_channels = %i[email]
  config.otp_login_channels = %i[email push]
end
```

```bash
bin/rails generate recording_studio_user:migrations
bin/rails db:migrate
```

Mount the OTP auth routes from this gem's `config/routes.rb`. Password sign-up and sign-in keep working. OTP users have no usable password and sign in with email codes only. See `MIGRATION_NOTES.md` for backfill details and route mapping.

Mounted profile show/edit/update still authenticate with Devise, then authorize with `RecordingStudioAccessible.authorized?` on the current user's Profile recording. Do not add a `current_user`-only ACL, `can_access?`, or hand-built Access rows.

Flash notices come from the host layout. Profile show does not render `notice` again. When the host uses Recording Studio's default layout, that layout already draws `flash[:notice]` as a FlatPack alert.

The profile PageNav right slot stays empty. Profile is not a place to grant other actors. First-owner bootstrap is how the owner is recorded; do not put `recording_access_management_link` on these screens.

Show puts **Edit** in the PageTitle actions slot (not in the card) and one Flatpack elevated Card. A Grid `cols: 2` wraps the Card only so it occupies one cell on a wide screen. Inside the card, Avatar sits above unlabeled name, email, and time zone — one column on desktop and phone. Empty photos use Avatar's person icon, not initials. There is no show subtitle and no city field. Edit hosts a `profile-photo` Turbo frame with Flatpack Avatar (`attachment_preview_url(..., variant: :square_med)`, `size: :"2xl"`, `shape: :circle`) plus Attachable `render_attachment_file_button` for Add/Change, then stacked fields, in a Flatpack Grid `cols: 2` so the form sits in one cell on large screens. An `mb-8` wrapper under the helper puts a field of air between the avatar and First name. First name, Last name, and Time zone stay full-width rows — not side by side. Update profile and Cancel are two separate Flatpack buttons sitting next to each other, not a ButtonGroup. Edit keeps the plain subtitle: "Change your name, time zone, or photo."

## Users administration

The engine still registers a reusable `users` section, a site-level `recording_studio_users` screen, and a compact total-users widget with `RecordingStudioAdmin`. The read-only screen lists name, email, and created-at. The gem does not add user editing, deletion, impersonation, password operations, or admin/role columns.

The host owns administration and must create its admin recordable/root, mount RecordingStudioAdmin, and grant first-owner `:admin` access on the empty owned admin root with `RecordingStudioAccessible.bootstrap_owner_access!`.

## Dummy app

The dummy keeps Devise login at `/users/sign_in` and sign up at `/users/sign_up`. Both are Devise views with Flatpack inputs and a primary button — not a Users product registration flow. Signed-in pages use core `recording_studio/default_layout` via `RecordingStudio::UsesDefaultLayout` (PageNav back/close). Devise pages keep `layouts/application` with `html data-theme="rounded"`. Dummy does not copy or override core's default layout. Core puts `data-theme="rounded"` on `body`; Flatpack named-theme tokens resolve on `html` / `:root`, so dummy's `recording_studio/_default_layout_head` sets `document.documentElement.dataset.theme` to `rounded` so primary buttons inherit charcoal, not `:root` blue.

Profile show/edit are that chrome only — no sidebar, Sign out, Root Switchable, or Access slot. Show is Avatar plus Edit at `:xl`. Edit hosts a `profile-photo` Turbo frame at `:"2xl"` (Flatpack `v0.1.135`) with Attachable's file button for Add/Change. Dummy still mounts Attachable and keeps a leftover attachment-show override (one core PageNav) if that URL is opened directly. Seeded accounts include:

| Email | Password |
| --- | --- |
| `admin@admin.com` | `Password` |
| `member@admin.com` | `Password` |

Seeded users get Profile snapshots under the shared People root, with Accessible `:admin` on each Profile recording. Avery Admin also gets a real image on that Profile recording. Dummy mounts notifications at `/notifications` (inbox and settings), email as a delivery channel, and push at `/notifications/push`. Workspace remains the host-owned bucket.

## Development

Run the standard validation from the repository root:

```bash
bundle exec rake test
bundle exec rake test:all
```

The dummy app's CI entrypoint is its lint and security workflow:

```bash
cd test/dummy
bin/ci
```
