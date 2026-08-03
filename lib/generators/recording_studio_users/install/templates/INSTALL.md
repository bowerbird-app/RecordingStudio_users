RecordingStudioUsers install complete.

Next steps:

1. Review `config/initializers/recording_studio_users.rb`.
2. Ensure your Devise `User` includes `RecordingStudioUsers::User`.
3. Install and migrate `recording_studio_accessible`.
4. Run `bin/rails db:migrate` to create the user root and profile tables.
5. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
6. Confirm the actor, current root, layout, user scope, and authorization resolvers match your host app.

Devise remains authoritative for authentication. Recording Studio Users owns the
private user-root and append-only profile topology created by its migrations.