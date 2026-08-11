RecordingStudioUser installed.

Next steps:

1. Run `bin/rails db:migrate`.
2. Create users directly or run `bin/rails db:seed`.
3. Configure your host-owned RecordingStudioAdmin root, access resolver, and site-admin recording resolver.
4. Enable the `users` section on the host recordable that owns your admin surface.

The installer registers the reusable users definitions, but it does not create an admin root,
access items, grants, or a fixed admin mount path. See the RecordingStudioUser README for the
complete host-side admin setup.
