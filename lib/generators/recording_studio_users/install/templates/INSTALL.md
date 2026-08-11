RecordingStudioUsers install complete.

Next steps:

1. Configure a persisted provisioning actor in `config/initializers/recording_studio_users.rb`.
2. Review the self-only identity, email, Profile, edit, stored-avatar, and search policies.
3. Run `bin/rails db:migrate`.
4. Ensure `Current.actor` and `Current.impersonator` are assigned per request.
5. Enable `:users` on the host RecordingStudioAdmin root with `section :users`.
6. Run `bin/rails recording_studio_users:backfill_profiles` for existing Users.
7. Build Tailwind assets and verify Devise registration, recovery, Profile, and avatar flows.
8. Confirm the installer added RecordingStudioUsers pins to `config/importmap.rb` and loaded its
	controller namespace from `app/javascript/controllers/index.js`. Follow the printed manual steps
	if the host uses a nonstandard JavaScript setup.

Private-root `admin` grants authority only inside that User's private root. They never grant site
RecordingStudioAdmin access. Stored-avatar routes can use only context-independent policies; when
the route cannot verify visibility, RecordingStudioUsers falls back to an external avatar or initials.

Blank locale and time-zone fields receive browser-derived defaults in the Profile form. These values
are not persisted until the User saves the form, and an existing saved value is never replaced.
