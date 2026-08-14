# RecordingStudioUser Reference App

This Rails application demonstrates RecordingStudioUser in a host application. It provides two capabilities:

- Global, authenticated editing of the signed-in user's profile.
- Access-controlled reporting on sitewide users with role-gated profile editing.

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run these commands from the dummy app directory. Sign in through Devise at `/users/sign_in` with one of the seeded accounts:

- `admin@admin.com` / `Password`: has `:admin` access to the Admin root and Studio Workspace, plus `:view` access to Client Workspace. Use this account to test workspace switching, the users report, and user profile editing.
- `member@admin.com` / `Password`: can view and edit their own profile but cannot access the Admin root, users report, or administrative profile editing.

## RecordingStudioUser Routes

- `/recording_studio_users/profile`: the signed-in user's global profile.
- `/recording_studio_users/profile/edit`: profile editing for the signed-in user.
- `/recording_studio_users/admin`: redirects authorized actors to the shared users-administration screen, where `:view` access permits reporting and details and `:admin` access permits profile editing.

Profile data is global to the current user. It is not recording-backed, recordable-backed, or root-scoped.

## Roots And Access

The dummy app has workspace roots and a separate host-owned Admin root. The seeded admin can switch between Studio Workspace and Client Workspace; Private Workspace remains inaccessible to demonstrate access filtering. The Admin root controls access to sitewide users reporting, and selecting a workspace neither grants Admin-root access nor changes profile data.

## Diagnostics

The `Recordable types`, `Recordings tree`, and `Gem Views` pages are dummy/developer diagnostics. They help inspect Recording Studio declarations, recording data, and shipped templates, but they are not core profile feature documentation.
