RecordingStudioUsers install complete.

Next steps:

1. Review `config/initializers/recording_studio_users.rb`.
2. Install and migrate `recording_studio_accessible`.
3. Enable the `:accessible` capability on each manageable root model.
4. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
5. Confirm the actor, current root, layout, user scope, and authorization resolvers match your host app.

Recording Studio Users has no migrations and does not own user authentication.