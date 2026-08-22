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

`recording_studio` (~> 4.2), `recording_studio_accessible` (~> 0.7), `recording_studio_attachable` (~> 0.4), `recording_studio_admin`, `flat_pack`, and `devise` are runtime dependencies. This gem enables Accessible and Attachable on Profile only. It does not enable either on People.

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
end
```

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

`attach_profile_image!` calls Attachable's `ImportAttachment` on the Profile recording. A second call returns the existing image. Swap files through Attachable's revision screen / `replace_attachment_file`.

`additional_profile_attributes` on configuration is an allowlist of extra keys stored in the Profile jsonb column. Identity, credential, authorization, membership, root, recording, and recordable fields stay protected.

Mounted profile show/edit/update still authenticate with Devise, then authorize with `RecordingStudioAccessible.authorized?` on the current user's Profile recording. Do not add a `current_user`-only ACL, `can_access?`, or hand-built Access rows.

Flash notices come from the host layout. Profile show does not render `notice` again. When the host uses Recording Studio's default layout, that layout already draws `flash[:notice]` as a FlatPack alert.

The profile PageNav right slot stays empty. Profile is not a place to grant other actors. First-owner bootstrap is how the owner is recorded; do not put `recording_access_management_link` on these screens.

Show puts **Edit** in the PageTitle actions slot and keeps **Swap this photo** next to the avatar. Edit lays first and last name in a Flatpack Grid and groups Update profile / Cancel in a ButtonGroup. Subtitles stay plain: "Your name, email, and photo." and "Change your name, time zone, or photo."

## Users administration

The engine still registers a reusable `users` section, a site-level `recording_studio_users` screen, and a compact total-users widget with `RecordingStudioAdmin`. The read-only screen lists name, email, and created-at. The gem does not add user editing, deletion, impersonation, password operations, or admin/role columns.

The host owns administration and must create its admin recordable/root, mount RecordingStudioAdmin, and grant first-owner `:admin` access on the empty owned admin root with `RecordingStudioAccessible.bootstrap_owner_access!`.

## Dummy app

The dummy keeps Devise login at `/users/sign_in`. Signed-in pages use core `recording_studio/default_layout` via `RecordingStudio::UsesDefaultLayout` (PageNav back/close). Devise pages keep `layouts/application` with `html data-theme="rounded"`. Dummy does not copy or override core's default layout. Rounded on profile pages is core's `body data-theme` (default `"rounded"`).

Profile show/edit are that chrome only — no sidebar, Sign out, Root Switchable, or Access slot. Attachable is mounted at `/recording_studio_attachable` with the same default layout so upload and replace stay rounded. Dummy overrides Attachable's attachment show to omit the gem's in-view PageNav so core owns the single back/close set. Seeded accounts include:

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
