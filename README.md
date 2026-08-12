# RecordingStudioUser

`RecordingStudioUser` is a reusable Rails engine for site-level user identity in
Recording Studio applications. It provides a UUID-backed Devise model, FlatPack
authentication and profile pages, and a reusable `RecordingStudioAdmin` users
report.

Profiles are ordinary global Active Record data. They are not recordings,
recordables, roots, events, or access resources, and they never depend on a
selected Recording Studio root.

## Dependencies

- `recording_studio`
- `flat_pack`
- `devise`
- `recording_studio_admin`

`recording_studio_accessible` is a host concern for protecting an admin root. The
profile feature does not use it.

## Install

```ruby
gem "recording_studio_user"
```

```sh
bundle install
bin/rails generate recording_studio_user:install
bin/rails db:migrate
bin/rails db:seed
```

The installer copies the user migration and initializer, adds Devise and singular
profile routes, registers admin definitions, and adds Tailwind `@source` entries
when `app/assets/tailwind/application.css` exists. The generated sources cover
host-vendored gems, standard RubyGems installs, and Bundler Git checkouts. The
installer is idempotent.

It never creates an admin root, mounts an admin route, creates access items, or
grants access. `recording_studio_user:admin` prints the focused host-registration
steps and is optional because the main installer enables registration.

## User and Devise

The default model is `RecordingStudioUser::User`, backed by the host `users`
table. It includes:

- email and Devise database-authentication fields;
- recoverable and rememberable fields;
- required first name, last name, and valid Rails time zone;
- UUID primary key and timestamps.

Enabled Devise modules are `database_authenticatable`, `recoverable`,
`rememberable`, and `validatable`. The gem owns its sign-in, reset-request,
reset-password, shared-link, and error views. They use FlatPack and the host
layout.

The generated route mapping is:

```ruby
devise_for :users,
           class_name: RecordingStudioUser.configuration.user_model,
           controllers: {
             sessions: "recording_studio_user/devise/sessions",
             passwords: "recording_studio_user/devise/passwords"
           }
```

## Profile

The installer adds a singular resource with stable helpers:

- `profile_path`
- `edit_profile_path`

Every action requires Devise authentication and operates only on `current_user`.
There is no user ID in the route. The default form permits only `first_name`,
`last_name`, and `time_zone`; email and password changes are not exposed.

## Configuration

```ruby
RecordingStudioUser.configure do |config|
  config.user_model = "RecordingStudioUser::User"
  config.profile_path = "profile"
  config.default_layout = "application"
  config.additional_permitted_profile_attributes = []
  config.admin_registration_hook = -> { RecordingStudioUser.register_admin! }
end
```

Changing `profile_path` changes the URL while retaining the singular helper names.
Additional permitted attributes require a compatible model column and a host view
override that renders the field.

A custom user class must be Devise-compatible, use the same authentication
mapping, expose `display_name`, `email`, `time_zone`, and `created_at`, and have a
schema compatible with the installed `users` table. Applications owning a
different table must own the corresponding migration. The gem does not claim to
migrate arbitrary custom models.

## RecordingStudioAdmin users reporting

The gem registers:

- section `users`, with `blast_radius :site`;
- screen `users`, with name, email, time zone, and created-at columns;
- a total-user metric linking to the screen;
- a total-users-over-time chart.

The report is read-only. It has no administrator-status field, editing, deletion,
or impersonation.

The host chooses placement and authorization. For example:

```ruby
class SiteAdmin < ApplicationRecord
  include RecordingStudioAdmin::AllowsAdminSections

  recording_studio_recordable label: "Admin", root: true
  RecordingStudio.enable_capability(:accessible, on: self)

  recording_studio_admin_sections do
    section :users
  end
end
```

Mount the surface wherever the host chooses:

```ruby
recording_studio_admin_for :admin, at: "/admin", root_section: :users
```

Configure both access and site blast-radius resolution:

```ruby
RecordingStudioAdmin.configure do |config|
  config.access_recording_resolver = ->(_context) { host_admin_root_recording }
  config.site_admin_recording_resolver = config.access_recording_resolver
end
```

Install and configure `RecordingStudioAccessible` in the host, enable its
capability on the chosen admin recordable, and use
`RecordingStudioAccessible.grant_access` to grant roles. This gem does not decide
who is an administrator and never adds a user boolean or role column.

## Dummy app

The dummy demonstrates:

- `My workspace`, a normal root;
- `Admin`, a distinct host-owned root enabling `section :users`;
- admin access granted with `RecordingStudioAccessible`;
- `My profile` in the authenticated FlatPack sidebar;
- a `Users admin` button on the admin root section.

Development credentials default to `admin@example.com` and `user@example.com`.
In development, the password defaults to `Password123!`. Set
`DUMMY_ADMIN_PASSWORD` and `DUMMY_USER_PASSWORD` before `db:seed` to override it.
Both password variables are required when seeding in any other environment.

```sh
cd test/dummy
bin/rails db:setup
bin/rails tailwindcss:build
bin/dev
```

## Upgrades and extension

Re-run the installer after upgrading; marker-based routes and exact Tailwind
sources are not duplicated. Review newly copied migrations before applying them.
Override the profile views or registration hook for compatible extensions rather
than editing gem files. User profiles must remain global and independent of
Recording Studio roots and access recordings.

## Validation

```sh
bundle exec rake test
bundle exec rake test:all
bundle exec rubocop
```
