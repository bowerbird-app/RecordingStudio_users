# RecordingStudioUser Reference App

This Rails application demonstrates RecordingStudioUser in a host application. It provides two capabilities:

- Global, authenticated editing of the signed-in user's profile.
- Access-controlled, read-only reporting on sitewide users.

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run these commands from the dummy app directory. Sign in through Devise at `/users/sign_in` with one of the seeded accounts:

- `admin@admin.com` / `Password`: has RecordingStudioAccessible `:admin` access to the host-owned Admin root and can view the users report.
- `member@admin.com` / `Password`: can use the profile pages but cannot access the Admin root or users report.

## RecordingStudioUser Routes

- `/recording_studio_users/profile`: the signed-in user's global profile.
- `/recording_studio_users/profile/edit`: profile editing for the signed-in user.
- `/recording_studio_users/admin`: the access-controlled, read-only users report.

Profile data is global to the current user. It is not recording-backed, recordable-backed, or root-scoped.

## Roots And Access

The dummy app has workspace roots and a separate host-owned Admin root. The Admin root controls access to sitewide users reporting; selecting a workspace neither grants Admin-root access nor changes profile data. Recording Studio root switching remains supported by the host application.

## Diagnostics

The `Recordable types`, `Recordings tree`, and `Gem Views` pages are dummy/developer diagnostics. They help inspect Recording Studio declarations, recording data, and shipped templates, but they are not core profile feature documentation.
