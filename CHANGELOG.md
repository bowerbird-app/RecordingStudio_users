# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.3] - 2026-08-21

### Added
- Added Devise host installation and `Current.actor` wiring.
- Added Accessible-backed invitations, membership management, and acceptance.
- Added zero-root onboarding and first-owner bootstrap for owned roots.
- Added session-backed, demotion-only operating roles with dual authorization checks.
- Added Root Switchable selection after root creation and invitation acceptance.

### Changed
- Productized and renamed the template as `recording_studio_users`.
- Updated the dummy app to prove the complete users flow with Flatpack UI.
- Requires Recording Studio 4.1+, Accessible 0.6.1+, and Root Switchable 0.5+.
- Tailwind now reads gem template paths from a list written before every build,
  replacing the guessed `vendor/bundle` globs that skipped FlatPack components.
- Styled the dummy app sign in and sign up screens with Flatpack and dropped the
  template's prefilled demo credentials.

### Fixed
- Accepting an invitation and removing a member now submit real forms. Both
  rendered a FlatPack button inside `button_to`'s own button, and browsers
  ignore clicks on a button nested in a button.
- The people screen is readable by any member of the root. It previously
  required admin, so a freshly invited member landed on a bare "Forbidden" page
  and an admin who put on a lower working role was locked out of the only screen
  that could give it back.
- Denied actions render an explanation instead of the bare text "Forbidden".

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_users/compare/v0.1.3...HEAD
[0.1.3]: https://github.com/bowerbird-app/RecordingStudio_users/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.0
