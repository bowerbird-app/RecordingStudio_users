# RecordingStudioUser

`RecordingStudioUser` is an isolated, mountable Rails engine. It keeps the host `User` as a Devise actor and owns **People** plus **Profile** as Recording Studio recordables.

- **User** stays the actor only: Devise, uuid, email, password. It is not a recordable and not a root.
- **People** is this gem's shared root (`label: "People"`, `root: true`, `shared: true`), the same idea as core's `MessagesRoot`. Workspace remains the host's owned bucket.
- **Profile** is the only child under People. One current profile per user, with `user_id` on the snapshot. User is not in the tree.

Accessible grants, Attachable avatars, and a redesigned profile/admin UI are later slices. This gem still ships the 0.1.x mounted profile routes and the read-only RecordingStudioAdmin users report.

## Installation

Add the engine to the host application's Gemfile:

```ruby
gem "recording_studio_user"
```

`recording_studio` (~> 4.2), `recording_studio_accessible`, `recording_studio_attachable`, `recording_studio_admin`, `flat_pack`, and `devise` are runtime dependencies. This slice does not enable Accessible or Attachable on People or Profile.

The host remains responsible for its existing User and Devise setup.

Then run:

```bash
bin/rails generate recording_studio_user:install
bin/rails generate recording_studio_user:migrations
bin/rails db:migrate
```

Register the gem's recordables next to the host's types. If `recording_studio_attachable` is bundled, also register its attachment type so core declaration validation can boot; do not enable Attachable on People or Profile in this slice:

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

People is a shared root. Nobody owns the forest through that root node; Accessible grants belong on later slices and on owned roots such as Workspace.

```ruby
class RecordingStudioUser::People < ApplicationRecord
  recording_studio_recordable label: "People", root: true, shared: true
end

class RecordingStudioUser::Profile < ApplicationRecord
  ALLOWED_PARENT_TYPES = ["RecordingStudioUser::People"].freeze

  recording_studio_recordable label: "Profile",
                              root: false,
                              allowed_parent_types: ALLOWED_PARENT_TYPES
end
```

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
```

`create_user!` creates the Devise user, then `people_root.record(Profile)`. Later changes `revise` the existing profile recording so a new snapshot row is created. `display_name_for` reads the current Profile, then a custom `full_name` / `name`, then email.

`additional_profile_attributes` on configuration is an allowlist of extra keys stored in the Profile jsonb column. Identity, credential, authorization, membership, root, recording, and recordable fields stay protected.

Granting access with `RecordingStudioAccessible.grant_access` waits for the Accessible slice. Do not invent a custom ACL.

## Users administration

The engine still registers a reusable `users` section, a site-level `recording_studio_users` screen, and a compact total-users widget with `RecordingStudioAdmin`. The read-only screen lists name, email, and created-at. The gem does not add user editing, deletion, impersonation, password operations, or admin/role columns.

The host owns administration and must create its admin recordable/root, mount RecordingStudioAdmin, and grant first-owner `:admin` access on the empty owned admin root with `RecordingStudioAccessible.bootstrap_owner_access!`.

## Dummy app

The dummy keeps the existing Devise login at `/users/sign_in`, root-switcher integration, and FlatPack layouts. Seeded accounts include:

| Email | Password |
| --- | --- |
| `admin@admin.com` | `Password` |
| `member@admin.com` | `Password` |

Seeded users get Profile snapshots under the shared People root. Workspace remains the host-owned bucket.

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
