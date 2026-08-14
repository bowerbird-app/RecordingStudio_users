# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_users/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.4
[0.1.3]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.3
[0.1.2]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.0
