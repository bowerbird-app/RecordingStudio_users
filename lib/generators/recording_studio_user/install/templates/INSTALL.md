# RecordingStudioUser installed

Next steps:

1. Run `bin/rails db:migrate`.
2. Create users with first name, last name, email, password, and a Rails time-zone name.
3. Run `bin/rails db:seed` if your application provides starter users.
4. Configure and mount your host-owned `RecordingStudioAdmin` surface.
5. Enable `section :users` on the host recordable used for administration.
6. Configure `RecordingStudioAdmin.site_admin_recording_resolver` for sitewide reporting.

The installer does not create an admin root, mount an admin surface, grant access, or
create `RecordingStudioAccessible` access items.
