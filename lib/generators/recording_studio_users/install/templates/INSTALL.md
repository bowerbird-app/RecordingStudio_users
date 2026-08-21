RecordingStudioUsers install complete.

Next steps:

1. Review `config/initializers/recording_studio_users.rb` and replace `Workspace` if your owned root has another name.
2. Enable Accessible on that root with `RecordingStudio.enable_capability(:accessible, on: Workspace)`.
3. Configure Root Switchable’s `workspaces` scope with `RecordingStudioAccessible.root_recordings_for`.
4. Run `bin/rails db:migrate`.
5. Run `bin/rails tailwindcss:build`.
6. Add links to `recording_studio_users.invitations_path` and `recording_studio_users.onboarding_path` in your app chrome.

Users identifies people, Accessible authorizes them, and Root Switchable chooses the current root. Do not add a Team model or a second access table.