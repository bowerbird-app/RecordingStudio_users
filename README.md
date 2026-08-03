# Recording Studio Users

`recording_studio_users` manages membership of the currently selected Recording
Studio root. It delegates grants, roles, and revocation to
`recording_studio_accessible`; authentication and user records remain owned by
the host application.

## Features

- Add an existing host user by email
- Assign `view`, `edit`, or `admin` access
- Change and revoke direct workspace access
- Fail-closed, configurable authorization
- Prevent removal or demotion of the final workspace admin
- FlatPack UI for a mounted Rails engine

## Install

```ruby
gem "recording_studio_users"
```

```ruby
# config/routes.rb
mount RecordingStudioUsers::Engine, at: "/recording_studio_users"
```

Install Recording Studio Accessible's migrations and enable its capability:

```ruby
class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  RecordingStudio.enable_capability(:accessible, on: self)
end
```

Configure host integration without coupling this engine to Devise:

```ruby
RecordingStudioUsers.configure do |config|
  config.current_actor_resolver = ->(controller:) { controller.current_user }
  config.current_root_resolver = ->(**) { RecordingStudio::RootSwitchable.current_root_recording }
  config.user_scope_resolver = ->(**) { User.active.order(:email) }
  config.layout = "application"
end
```

The default authorizer requires `admin` access on the current root.
`user_resolver`, `user_label_resolver`, and `authorizer` are configurable.

## Development

```bash
bundle exec rake test
bundle exec rake test:all
```

The dummy login is `admin@admin.com` / `Password`.
