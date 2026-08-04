# Public API

Configuration: `configure`, `configuration`, and `user_class`.

Topology: `provision`, `provisioned?`, `user_root_for`, `user_root_recording_for`,
`profile_recording_for`, `profile_for`, `avatar_recording_for`, and
`validate_user_profile!`. Lookup and validation never write or repair.

Mutations: `revise_profile`, `upload_avatar`, `replace_avatar`, `remove_avatar`, and
`log_user_event`. Mutations return `RecordingStudioUsers::Result`.

Policies: `identity_visible?`, `email_visible?`, `profile_visible?`, `profile_editable?`, and
`stored_avatar_visible?`.

Presentation: `display_name`, `initials`, `avatar_for`, `profile_path_for`, and
`profile_complete?`. Helpers do not provision or repair.

Collections: `preload_user_information` and `search_users`.

Unknown avatar sizes, Profile attributes, event actions, and configuration values are rejected.
Dependency failures are translated only at the public service boundary.
