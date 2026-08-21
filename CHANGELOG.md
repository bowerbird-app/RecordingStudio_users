# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-08-21

### Changed
- First-owner access on a new Profile recording uses `RecordingStudioAccessible.bootstrap_owner_access!` (role `:admin`). Later membership still uses `grant_access`.
- Removed the Users paper-over that swapped `access_management_authorizer` / retried `grant_first_owner` when the Profile had no admin yet.
- Pinned `recording_studio_accessible` to `~> 0.7` (tag `v0.7.0`). Accessible 0.7.0 allows bootstrap on an accessible child under a shared root (Profile under People).

### Upgrade notes
- Upgrade RecordingStudioAccessible to `0.7.0` before installing this gem. 0.6.1 still rejects Profile bootstrap with `Recording must be a root recording`.
- Call `create_user!` / `record_profile!` for signup and backfill. Those helpers bootstrap the Profile recording only — never People.
- Replace any host use of `ProfileAccess.ensure_owner_access!` or an `access_management_authorizer` mutex with `bootstrap_owner_access!` on the Profile recording, then `grant_access` for later members.
- Do not bootstrap People. Do not bootstrap owned-root children. Do not enable Accessible on People.

## [0.3.0] - 2026-08-21

### Added
- Enabled Recording Studio Accessible on **Profile** with `RecordingStudio.enable_capability(:accessible, on: self)`. People stays a shared root without Accessible.
- `create_user!` and `record_profile!` grant the user `:admin` on their Profile recording through `RecordingStudioAccessible.grant_access`.
- Profile show, edit, and update authorize with `RecordingStudioAccessible.authorized?` on that Profile recording. The leftover 0.1.5 screens now read and revise Profile snapshot fields so those requests do not 500 on missing User columns.

### Changed
- Removed the Devise `current_user`-only profile ACL. Authentication is still Devise; authorization is Accessible.
- Users administration is unchanged: Admin root + Accessible, not `user.admin?`.
- Updated the development and dummy app RecordingStudioAdmin pin to 2.0.1. Direct browser visits to admin frame endpoints now redirect to their styled parent screen while Turbo Frame requests still return fragments.

### Upgrade notes
- Register `RecordingStudioUser::Profile` (and People) in `config.recordable_types`. Keep `access_actor_types` configured so User can receive grants.
- Create or backfill profiles with `create_user!` / `record_profile!` so each user receives an Accessible grant on their Profile recording. A Profile row without a grant is forbidden on the mounted profile routes.
- Do not enable Accessible on People. Do not grant on the shared People root.
- Existing hosts that created Profile recordings in 0.2.0 without grants should call `record_profile!` (or `ProfileAccess.ensure_owner_access!`) once per user.
- Upgrade RecordingStudioAdmin to 2.0.1 or newer so opening `/screens/:key/chart`, `/table`, `/table_count`, and widget frame URLs as pages returns the styled parent screen.

## [0.2.0] - 2026-08-21

### Breaking
- User is now the Devise actor only. Host User no longer stores `first_name`, `last_name`, `time_zone`, or `additional_profile_attributes`.
- This gem now owns **People** (`root: true`, `shared: true`, label `"People"`) and **Profile** as a child under People, with `user_id` on the Profile snapshot.
- `display_name_for` reads the current Profile snapshot, not User name columns.
- Signup-shaped writes go through `RecordingStudioUser.create_user!` / `record_profile!`, which call `people_root.record(Profile)` and `revise`. Do not insert `Recording` or `Event` rows directly.

### Added
- People and Profile recordable models, engine migrations, and `recording_studio_user:migrations`.
- Dummy pins for RecordingStudio `v4.2.0`, Accessible `v0.6.1`, Attachable `0.4.0`, and FlatPack `v0.1.133`. Accessible and Attachable are bundled but not enabled on People or Profile. Dummy registers `RecordingStudioAttachable::Attachment` so declaration validation can boot.

### Changed
- Gemspec now requires `recording_studio ~> 4.2` plus `recording_studio_accessible` and `recording_studio_attachable`. Dropped unused `pagy`.
- Users admin table no longer reads a User time zone column.

### Upgrade notes
- Remove `first_name`, `last_name`, `time_zone`, and `additional_profile_attributes` from the host User table and model. Those fields live on Profile.
- Register `RecordingStudioUser::People` and `RecordingStudioUser::Profile` in `config.recordable_types`.
- Run `bin/rails generate recording_studio_user:migrations` and `db:migrate`.
- Create users with `RecordingStudioUser.create_user!(email:, password:, first_name:, last_name:, time_zone:)` or `User.create!` then `people_root.record(Profile)`.
- Accessible grants and Attachable avatars are not enabled in 0.2.0. Do not add a custom ACL while waiting for those slices.

## [0.1.5] - 2026-08-21

### Changed
- Restored the users-admin capability to a read-only report: the gem no longer ships user show/edit routes or role-gated admin profile editing.
- Pointed the users section at the RecordingStudioAdmin screen path so the users report is enabled, and kept the total-users widget on the mounted `recording_studio_users.admin_path` helper.
- Used the dummy host sidebar layout for profile pages and the mounted profile helper for **My profile**.
- Preserved the original Devise users migration and kept profile columns in a host-owned additive migration.
- Installer now also injects resolved relative Tailwind `@source` paths for this engine and FlatPack when those locations can be determined.
- Dummy app pins FlatPack Stimulus controllers under `controllers/flat_pack`, generates gem Tailwind sources before each CSS build, and watches CSS without requiring watchman.
- Bumped development and dummy pins to RecordingStudio `4.2.0`, Accessible `0.6.1`, Root Switchable `0.5.0`, FlatPack `0.1.133`, and RecordingStudioAdmin `2.0.0`.
- Dummy sidebar items and buttons use FlatPack 0.1.133's `text:` / `href:` arguments.
- Dummy seeds and integration tests grant first-owner access with `RecordingStudioAccessible.bootstrap_owner_access!` instead of `AccessCreationContext.allow`.

### Upgrade notes
- Remove any host links or tests that called gem-owned admin user show/edit/update routes. Users administration is a read-only report.
- If the users report screen does not appear, make sure the `:users` section links with `context.admin_screen_path("recording_studio_users")` so RecordingStudioAdmin enables that screen.
- Rebuild host Tailwind CSS after install (`bin/rails tailwindcss:build`). If FlatPack layout utilities are missing, add an `@source` that points at the installed `flat_pack` `app/components` directory.
- Pin FlatPack controllers with `under: "controllers/flat_pack"` so Stimulus can load `flat-pack--*` controllers.
- Upgrade RecordingStudio to `~> 4.1`, Accessible to `~> 0.6` (prefer `0.6.1` for `bootstrap_owner_access!`), and RecordingStudioAdmin to `~> 2.0` before installing this gem. Run the RecordingStudio harden-indexes migration (`rails g recording_studio:migrations` or the equivalent host migration) and `db:migrate`.
- Use `RecordingStudioAccessible.bootstrap_owner_access!(recording:, actor:)` for the first `:admin` grant on an empty owned root. Use `grant_access` for later invites.
- FlatPack `0.1.133` buttons take `href:` (not `url:`) and sidebar items take `text:` (not `label:`).

## [0.1.4] - 2026-08-14

### Added
- Added a shared RecordingStudioAdmin users screen with sitewide totals, creation-over-time reporting, filtering, user details, and protected table actions.
- Added dummy-app workspace and Admin-root fixtures demonstrating RecordingStudioAccessible access filtering.

### Changed
- Updated the profile page layout and added root-aware profile and users-administration navigation to the dummy app.
- Restricted user profile edits to actors with `:admin` access while retaining report and detail access for actors with `:view` access.
- Moved users administration rendering and navigation to the configured RecordingStudioAdmin surface.

### Security
- Added authorization and site blast-radius checks around users reporting and user-table actions.

## [0.1.3] - 2026-08-14

### Changed
- Released RecordingStudioUser version `0.1.3`.

## [0.1.2] - 2026-07-21

### Changed
- Bumped the dummy app FlatPack dependency from `v0.1.33` to `v0.1.129`

## [0.1.1] - 2026-04-28

### Changed
- Bumped the dummy app FlatPack dependency from `0.1.2` to `0.1.33` and pinned it by tag in `test/dummy/Gemfile`

## [0.1.0] - 2025-12-04

### Added
- Initial release
- Rails mountable engine structure
- PostgreSQL with UUID primary keys support
- TailwindCSS v4 integration
- GitHub Codespaces devcontainer configuration
- Docker Compose setup with PostgreSQL and Redis
- Install generator for host applications
- Comprehensive README and documentation
- Basic test suite with Minitest

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_users/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.2.0
[0.1.5]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.5
[0.1.4]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.4
[0.1.3]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.3
[0.1.2]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.0
