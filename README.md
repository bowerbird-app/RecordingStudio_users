# RecordingStudioUser

`RecordingStudioUser` is an isolated, mountable Rails engine for two focused capabilities:

- authenticated, global profiles for the host application's existing user model;
- a reusable, read-only `RecordingStudioAdmin` users report.

The template already owns `User`, the users table, Devise, and the login page. This gem does not regenerate or replace them. It does not determine administrators, create an admin root, create access grants, or add user roles.

## Installation

Add the required dependencies:

```ruby
gem "recording_studio_user"
gem "recording_studio"
gem "flat_pack"
gem "devise"
gem "recording_studio_admin"
```

Then run:

```bash
bin/rails generate recording_studio_user:install
```

The installer is idempotent. It copies a non-overwriting initializer, mounts the engine once as `recording_studio_users`, and adds missing Tailwind source directives when the host uses Tailwind. It does not generate a user model, users table, Devise routes, migrations, admin root, access item, role, or grant.

Route configuration must load **before Rails draws routes**:

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

The default URLs are:

- `/recording_studio_users/profile`
- `/recording_studio_users/profile/edit`
- `/recording_studio_users/admin`

Host code uses the mounted-engine proxy:

```ruby
recording_studio_users.profile_path
recording_studio_users.edit_profile_path
recording_studio_users.admin_path
```

No unscoped host `profile_path`, `edit_profile_path`, or `admin_path` helper is added.

## User contract and profiles

The configured `user_class_name` must name the existing, Devise-compatible Active Record class returned by `current_user`. It must use the host's UUID primary key and provide `email`, `first_name`, `last_name`, `time_zone`, and timestamps. The engine applies presence and Rails-time-zone validation to the profile fields while preserving Devise email validation.

Profiles are global site data, not Recording Studio recordings, recordables, or root-scoped resources. Profile authorization uses `current_user` only; it never accepts a user ID and does not require `RecordingStudioAccessible` or a selected root. Root switching does not alter profile data.

By default, only `first_name`, `last_name`, and `time_zone` are writable. `additional_profile_attributes` may name safe host attributes. Sensitive fields, including identifiers, email, passwords, roles, memberships, roots, recordings, and recordables, are rejected even when configured.

Email and password changes remain in the host's existing Devise flows.

## Users administration

The engine registers a `users` section, a site-level `recording_studio_users` screen, and a compact total-users widget with `RecordingStudioAdmin`. The screen is read-only and contains name, email, time zone, created-at, total-user, and creation-over-time reporting.

The host owns administration and must:

1. create its own admin recordable/root;
2. install and configure `RecordingStudioAccessible`;
3. configure `RecordingStudioAdmin` access-recording and site-admin-recording resolvers;
4. enable the reusable section on its chosen recordable;
5. grant access through Recording Studio access items and roles.

For example, using the actual section API:

```ruby
class AdminRoot < ApplicationRecord
  include RecordingStudioAdmin::AllowsAdminSections

  recording_studio_recordable label: "Admin", root: true
  RecordingStudio.enable_capability(:accessible, on: self)

  recording_studio_admin_sections do
    section :users
  end
end
```

The page calls RecordingStudioAdmin's configured authorization and site blast-radius checks. Unauthorized actors are rejected regardless of this engine's mount path. The profile capability remains independent of Accessible.

## UI

Gem-owned full pages use:

```text
[FlatPack page title]
[content]
```

They use the configured host layout and contain no outer card around the profile form/display or users report. `RecordingStudioAdmin` may render its own supported widgets internally.

## Dummy app

The dummy keeps the existing Devise login at `/users/sign_in`, root-switcher integration, and FlatPack layouts. Seeded accounts include:

| Email | Password |
| --- | --- |
| `admin@admin.com` | `Password` |
| `member@admin.com` | `Password` |

The dummy demonstrates separate **My workspace** and access-controlled **Admin** roots. Its sidebar includes **My profile**. Admin access is granted with `RecordingStudioAccessible`, never a user role field.

## Development

Run the standard validation from the repository root:

```bash
bundle exec rake test
bundle exec rake test:all
```

When upgrading, preserve the host-owned User/Devise contract and rerun the installer safely. Add extension fields only through the documented configuration and keep any admin-root, resolver, and grant changes in the host application.
