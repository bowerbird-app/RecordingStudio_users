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

`recording_studio` (~> 4.2), `recording_studio_accessible` (~> 0.7), `recording_studio_attachable` (~> 0.5.0), `recording_studio_admin`, `flat_pack` (~> 0.1.142), `devise`, `omniauth`, `omniauth-google-oauth2`, `omniauth-microsoft_graph`, `omniauth-apple`, `omniauth-linkedin-openid`, `omniauth-instagram-api`, and `omniauth-rails_csrf_protection` are runtime dependencies. This gem enables Accessible and Attachable on Profile only. It does not enable either on People.

The host remains responsible for its existing User and Devise setup, Active Storage, and the Attachable mount. OmniAuth secrets stay in host credentials or ENV.

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
  # config.login_title = "Welcome back"
  config.omniauth_providers = {
    google_oauth2: {
      client_id: Rails.application.credentials.dig(:google_oauth, :client_id) || ENV["GOOGLE_CLIENT_ID"],
      client_secret: Rails.application.credentials.dig(:google_oauth, :client_secret) || ENV["GOOGLE_CLIENT_SECRET"]
    },
    microsoft_graph: {
      client_id: ENV["MICROSOFT_CLIENT_ID"],
      client_secret: ENV["MICROSOFT_CLIENT_SECRET"]
    },
    apple: {
      client_id: ENV["APPLE_CLIENT_ID"],
      client_secret: "",
      team_id: ENV["APPLE_TEAM_ID"],
      key_id: ENV["APPLE_KEY_ID"],
      pem: ENV["APPLE_PEM"],
      scope: "email name"
    },
    linkedin: {
      client_id: ENV["LINKEDIN_CLIENT_ID"],
      client_secret: ENV["LINKEDIN_CLIENT_SECRET"]
    },
    instagram: {
      client_id: ENV["INSTAGRAM_CLIENT_ID"],
      client_secret: ENV["INSTAGRAM_CLIENT_SECRET"]
    }
  }
  config.omniauth_create_account = true
end
```

When providers is empty, login looks as today (no Continue buttons). Host Devise must use Users' callback controller:

```ruby
devise_for :users, controllers: {
  omniauth_callbacks: "recording_studio_user/omniauth_callbacks"
}
```

`omniauth_create_account` defaults to `true`. When `false`, unknown provider emails do not create a User.

## OmniAuth providers (Google, Microsoft, Apple, LinkedIn, Instagram)

Users owns OmniAuth behavior: config, identities, callbacks, find-or-create, Sign-in methods UI, and the login/sign-up Continue partial. The host keeps the Devise `User` model and `devise_for :users`. Identities live on the User only — not a recordable, not in the People tree. One User, many identities. Password can stay; disconnect does not delete the User.

Strategy gems (registered by provider key, not a Google-only branch):

| Config key | Gem | Label |
|---|---|---|
| `google_oauth2` | `omniauth-google-oauth2` | Google |
| `microsoft_graph` | `omniauth-microsoft_graph` | Microsoft |
| `apple` | `omniauth-apple` | Apple |
| `linkedin` | `omniauth-linkedin-openid` | LinkedIn |
| `instagram` | `omniauth-instagram-api` | Instagram |

Instagram uses **Instagram API with Instagram Login** (`omniauth-instagram-api`) — Instagram app client id/secret. That is different from older Facebook-Login Instagram Graph strategies.

**Email caveats (fail closed on first login without email — `MissingEmailError`):** Instagram often returns no email. Apple may send email only on first consent (or a private relay); later visits match Identity by uid. Connect while already signed in still works and does **not** invent an email (`Identity.email` may be blank).

Find-or-create used by the callback:

1. Find Identity by provider+uid → that User.
2. Else find User by email → create Identity, return User.
3. Else if `omniauth_create_account` → `create_user!` / `record_profile!` (name from OmniAuth when present, timezone UTC), create Identity, return User.
4. Else fail closed.

Provider-only users get an unusable blank password digest; `password_required?` is false while they have at least one identity. Connect on the owner-only **Sign-in methods** page attaches the provider to the signed-in User. Disconnect refuses if that Identity is the only sign-in method and the user has no password.

Render the Flatpack partial on host Devise login and sign-up after the primary button and account cross-link. When any provider is configured it paints a labeled Or divider and one full-width secondary Continue button per provider (logo via `icon:` when the logo is inline SVG):

```erb
<%= render "recording_studio_user/omniauth/continue_with_providers" %>
```

Optional `omniauth_providers[:provider][:logo]` accepts a URL or inline SVG. The gem ships a default SVG for each of the five. Flatpack List has no first-class image-URL lead — SVG uses `icon:`, URLs use `leading:` with an `<img>`. Continue buttons pass SVG logos through Button `icon:` (Users prepends SVG support onto Flatpack Button until Flatpack mirrors List). `:logo` is stripped before Devise strategy registration.

My Profile show stays read-only (Edit + Sign-in methods actions). Connect / Disconnect live only on Sign-in methods (`…/profile/sign-in-methods`) as matching Card + List rows (logo + provider name; Connect or Disconnect trailing, secondary sm). Edit has no Sign-in methods link.

Host code uses the mounted-engine proxy:

```ruby
recording_studio_users.profile_path
recording_studio_users.edit_profile_path
recording_studio_users.admin_path
```

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

`login_title` defaults to `"Welcome back"` for the host Devise login heading. Blank values fall back to that default.

Mounted profile show/edit/update still authenticate with Devise, then authorize with `RecordingStudioAccessible.authorized?` on the current user's Profile recording. Do not add a `current_user`-only ACL, `can_access?`, or hand-built Access rows.

Flash notices come from the host layout. Profile show does not render `notice` again. When the host uses Recording Studio's default layout, that layout already draws `flash[:notice]` as a FlatPack alert.

The profile PageNav right slot stays empty. Profile is not a place to grant other actors. First-owner bootstrap is how the owner is recorded; do not put `recording_access_management_link` on these screens.

Show puts **Edit** and **Sign-in methods** (when OmniAuth is configured) in the PageTitle actions slot and one Flatpack elevated Card. A Grid `cols: 2` wraps the Card only so it occupies one cell on a wide screen. Inside the card, Avatar sits above unlabeled name, email, and time zone — one column on desktop and phone. Empty photos use profile-name initials (never the word “Avatar”). There is no show subtitle and no city field. Show omits `page_nav_back_url` / `page_nav_back_label` (root owner page). Core `default_layout` still mounts Flatpack PageNav, which always paints a history.back control — hiding it needs Flatpack/core, not a Users fork or CSS hide. Edit hosts a `profile-photo` Turbo frame with Flatpack Avatar (`attachment_preview_url(..., variant: :square_med)`, `size: :"2xl"`, `shape: :circle`, `name`/`alt` from the profile display name, `show_tooltip: false`) plus Attachable `render_attachment_file_button` for Add/Change, then stacked fields, in a Flatpack Grid `cols: 2` so the form sits in one cell on large screens. An `mb-8` wrapper under the helper puts a field of air between the avatar and First name. First name, Last name, and Time zone stay full-width rows — not side by side. Update profile and Cancel are two separate Flatpack buttons sitting next to each other, not a ButtonGroup. Edit PageTitle stays **Edit Profile**; the subtitle is the profile name at default muted size (not `large_subtitle`). Edit is photo + name + timezone only — no Sign-in methods link. Sign-in methods is a separate owner-only page (elevated Card + List): connected identities show logo, name, email, and Disconnect; when Google is configured but not linked, the same row shape shows logo, “Google”, and Connect (secondary, sm).

## Users administration

The engine still registers a reusable `users` section, a site-level `recording_studio_users` screen, and a compact total-users widget with `RecordingStudioAdmin`. The read-only screen lists name, email, and created-at. The gem does not add user editing, deletion, impersonation, password operations, or admin/role columns.

The host owns administration and must create its admin recordable/root, mount RecordingStudioAdmin, and grant first-owner `:admin` access on the empty owned admin root with `RecordingStudioAccessible.bootstrap_owner_access!`.

## Dummy app

The dummy keeps Devise login at `/users/sign_in` and sign up at `/users/sign_up`. Both use the same Flatpack auth stack with a Grid `cols: 2` width cap (no Card): `login_title` (default **Welcome back**) / **Sign up**, fields, primary Sign in / Sign up, cross-link, Flatpack Divider `Or`, then full-width **Continue with {Provider}** secondary buttons for every configured OmniAuth provider — not a Users product registration flow. Login does not show Remember me (Devise rememberable may stay on). Sign-up password confirmation stays host-configurable. The login seed hint sits under the form. OmniAuth runs in test mode with mocks for Google, Microsoft, Apple, LinkedIn, and Instagram so CI and screenshots do not need live apps. Signed-in pages use core `recording_studio/default_layout` via `RecordingStudio::UsesDefaultLayout` (PageNav back/close). Devise pages keep `layouts/application` with `html data-theme="rounded"`. Dummy does not copy or override core's default layout. Core puts `data-theme="rounded"` on `body`; Flatpack named-theme tokens resolve on `html` / `:root`, so dummy's `recording_studio/_default_layout_head` sets `document.documentElement.dataset.theme` to `rounded` so primary buttons inherit charcoal, not `:root` blue. Dummy pins Flatpack `v0.1.142` for Divider.

Profile show/edit are that chrome only — no sidebar, Sign out, Root Switchable, or Access slot. Show is Avatar plus Edit and Sign-in methods at `:xl`. Edit hosts a `profile-photo` Turbo frame at `:"2xl"` (Flatpack `v0.1.142`) with Attachable's file button for Add/Change. Connect / Disconnect live on `/recording_studio_users/profile/sign-in-methods`. Dummy still mounts Attachable and keeps a leftover attachment-show override (one core PageNav) if that URL is opened directly. Seeded accounts include:

| Email | Password |
| --- | --- |
| `admin@admin.com` | `Password` |
| `member@admin.com` | `Password` |

Seeded users get Profile snapshots under the shared People root, with Accessible `:admin` on each Profile recording. Avery Admin also gets a real image on that Profile recording. Workspace remains the host-owned bucket.

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
