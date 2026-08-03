Recording Studio Users has been installed at /recording_studio_users.

Review config/initializers/recording_studio_users.rb, ensure your Devise User
includes RecordingStudioUsers::User, install recording_studio_accessible, run
bin/rails db:migrate, and rebuild Tailwind CSS. Devise remains authoritative for
authentication; this engine owns the private user-root and profile topology.
