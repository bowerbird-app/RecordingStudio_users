# RecordingStudioUser

`RecordingStudioUser` is an isolated, mountable Rails engine for two focused capabilities:

- authenticated, global profiles for the host application's existing user model;
- a reusable, read-only `RecordingStudioAdmin` users report.

The template already owns `User`, the users table, Devise, and the login page. This gem does not regenerate or replace them. Profiles are global data, not recordings, recordables, or root-scoped resources. Profile authorization uses `current_user`, not `RecordingStudioAccessible`. The gem does not determine administrators; admin access is host-owned and recording-based. `RecordingStudioRootSwitchable` remains supported, and profile data is unaffected by root switching.

## Installation

Add the engine to the host application's Gemfile:

```ruby
gem "recording_studio_user"
```

`recording_studio`, `flat_pack`, `devise`, and `recording_studio_admin` are required runtime dependencies and are resolved through this gem's gemspec. `recording_studio_accessible` is required by a host only when protecting the users admin capability through an access-controlled admin root. The profile feature itself does not require it.

The host remains responsible for configuring its existing User and Devise setup.

Then run:

```bash
bin/rails generate recording_studio_user:install
```

Rerunning the installer is idempotent while the generated mount declaration remains intact. It mounts the engine with the `recording_studio_users` alias, creates `config/initializers/recording_studio_user.rb` only when that file does not already exist, and conditionally adds missing RecordingStudioUser and FlatPack Tailwind source directives when the host has a Tailwind entrypoint containing `@import "tailwindcss";`. It does not generate or copy migrations, or generate a user model, users table, Devise routes, admin root, access item, role, or grant. The main installer does not invoke a separate admin generator; host apps create the admin root, resolvers, access items, and grants themselves.

Route configuration values for `mount_path`, `profile_route_path`, and `admin_route_path` must be available **before the host evaluates the engine mount and Rails draws routes**. An ordinary initializer that runs after routes have been drawn cannot change the mounted path or engine route paths:

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

This produces:

- `/account/me`
- `/account/me/edit`
- `/account/user-reporting`

The default URLs are:

- `/recording_studio_users/profile`
- `/recording_studio_users/profile/edit`
- `/recording_studio_users/admin`

There is no landing page at `/recording_studio_users`.

Host code uses the mounted-engine proxy:

```ruby
recording_studio_users.profile_path
recording_studio_users.edit_profile_path
recording_studio_users.admin_path
```

No unscoped host `profile_path`, `edit_profile_path`, or `admin_path` helper is added. Route changes do not alter or bypass authentication or admin authorization.

## User contract and profiles

The configured `user_class_name` must name the existing, Devise-compatible Active Record class returned by `current_user`. It must use the host's UUID primary key and provide `email`, `first_name`, `last_name`, `time_zone`, and timestamps. The engine applies presence and Rails-time-zone validation to the profile fields while preserving Devise email validation. A custom user class must remain compatible with host authentication. The host owns its model and migrations.

If the model already has `full_name` or `display_name`, the gem uses it. Otherwise it falls back to the available name, email, or a neutral translated label.

Profiles are global site data, not Recording Studio recordings, recordables, or root-scoped resources. Profile authorization uses `current_user` only; it never accepts a user ID and does not require `RecordingStudioAccessible` or a selected root. Showing or updating a profile does not create recordings, recordables, roots, events, or Accessible access items. Root switching does not alter profile data.

By default, only `first_name`, `last_name`, and `time_zone` are writable. `additional_profile_attributes` may name safe host attributes. Sensitive fields, including identifiers, email, passwords, roles, memberships, roots, recordings, and recordables, are rejected even when configured.

Email and password changes remain in the host's existing Devise flows.

## Users administration

The engine registers a reusable `users` section, a site-level `recording_studio_users` screen, and a compact total-users widget with `RecordingStudioAdmin`. The read-only screen contains name, email, time zone, created-at, a total-users metric, and a users-over-time chart. The gem does not add user editing, deletion, impersonation, password operations, or admin/role columns.

The host owns administration and must:

1. create its own admin recordable/root;
2. install and configure `RecordingStudioAccessible`;
3. mount the `RecordingStudioAdmin` engine;
4. configure `RecordingStudioAdmin` access-recording and site-admin-recording resolvers;
5. enable the reusable section on its chosen recordable;
6. grant first-owner `:admin` access on the empty owned admin root with `RecordingStudioAccessible.bootstrap_owner_access!`, then use `grant_access` for later invites.

Mount the shared admin surface in the host routes. The engine's `/recording_studio_users/admin` URL authorizes the actor and then renders the shared `RecordingStudioAdmin` users screen:

```ruby
recording_studio_admin_for :admin, at: "/admin", root_section: :root
mount RecordingStudioUser::Engine => RecordingStudioUser.config.mount_path, as: :recording_studio_users
```

The users section links to the shared RecordingStudioAdmin users screen, which is how that engine enables the screen for the host's admin recordable. Host navigation should use `recording_studio_users.admin_path`, which authorizes the actor and then opens that same screen. Changing this engine's mount path does not weaken authorization; the page still authorizes through the host-resolved admin recording.

Configure the admin authorization resolvers in the host application. This example follows the dummy app and resolves the host-owned `AdminRoot` recordable:

```ruby
RecordingStudioAdmin.configure do |config|
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.access_recording_resolver = lambda do |_context|
    admin_root = AdminRoot.find_by(name: "Admin")
    RecordingStudio.root_recording_for(admin_root) if admin_root
  end
  config.site_admin_recording_resolver = config.access_recording_resolver
end
```

Enable the reusable section on the host's chosen admin recordable using the real `RecordingStudioAdmin` section API:

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

The page calls RecordingStudioAdmin's configured authorization and site blast-radius checks. Unauthorized actors are rejected regardless of this engine's mount path. Admin roots, resolver targets, access items, roles, and grants are all host-owned. The profile capability remains independent of Accessible.

## UI

Gem-owned pages use:

```text
[FlatPack page title]
[content]
```

They use the configured host layout and contain no outer card around the profile display, profile form, or a gem-owned admin wrapper. Users administration is rendered by `RecordingStudioAdmin` and uses that gem's configured layout and supported components. If RecordingStudioAdmin internally renders a widget with a card-like component, this gem does not add another outer card around the screen.

## Dummy app

The dummy keeps the existing Devise login at `/users/sign_in`, root-switcher integration, and FlatPack layouts. Seeded accounts include:

| Email | Password |
| --- | --- |
| `admin@admin.com` | `Password` |
| `member@admin.com` | `Password` |

The dummy demonstrates separate **My workspace** and access-controlled **Admin** roots. Its sidebar includes **My profile**, and selecting the Admin root exposes the Users admin action through `recording_studio_users.admin_path`. The seeded admin can switch among accessible workspaces and open the users report; the seeded member can use profile pages but cannot see or reach the Admin root. Admin access is granted with `RecordingStudioAccessible`, never a user role field. Switching roots does not change profile data.

## Development

Run the standard validation from the repository root:

```bash
bundle exec rake test
bundle exec rake test:all
```

The dummy app's CI entrypoint is its lint and security workflow, rather than the engine test suite:

```bash
cd test/dummy
bin/ci
```

When upgrading, preserve the host-owned User/Devise contract and rerun the installer safely. Add extension fields only through the documented configuration and keep any admin-root, resolver, and grant changes in the host application.
