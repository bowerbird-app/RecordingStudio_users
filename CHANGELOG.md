# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_users/compare/v0.1.5...HEAD
[0.1.5]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.5
[0.1.4]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.4
[0.1.3]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.3
[0.1.2]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.0
